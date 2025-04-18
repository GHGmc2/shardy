/* Copyright 2025 The Shardy Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

#include "shardy/round_trip_import/shard_map_import.h"

#include <cassert>
#include <memory>
#include <utility>

#include "llvm/ADT/StringRef.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/Support/ErrorHandling.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/Diagnostics.h"
#include "mlir/IR/DialectRegistry.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/IR/SymbolTable.h"
#include "mlir/IR/TypeRange.h"
#include "mlir/IR/Value.h"
#include "mlir/IR/ValueRange.h"
#include "mlir/IR/Visitors.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Pass/PassManager.h"
#include "mlir/Pass/PassRegistry.h"
#include "mlir/Support/LLVM.h"
#include "mlir/Support/TypeID.h"
#include "mlir/Transforms/DialectConversion.h"
#include "shardy/dialect/sdy/ir/dialect.h"
#include "shardy/dialect/sdy/ir/utils.h"
#include "shardy/round_trip_import/constants.h"
#include "shardy/round_trip_import/utils.h"
#include "stablehlo/dialect/StablehloOps.h"

namespace mlir {
namespace sdy {

namespace {

using ::mlir::func::CallOp;
using ::mlir::func::FuncOp;
using ::mlir::stablehlo::CustomCallOp;

// Converts a CallOp calling a @xla.sdy.manual_computation_body func with in/out
// shardings and manual axes as frontend attrs, wrapped with custom calls that
// change the shape of the arguments/results to a `ManualComputationOp`. See
// `SdyRoundTripShardMapExportPass` for its counterpart.
class ManualComputationPattern : public OpConversionPattern<CallOp> {
 public:
  explicit ManualComputationPattern(MLIRContext* context,
                                    const SymbolTable& symbolTable)
      : OpConversionPattern<CallOp>(context), symbolTable(symbolTable) {}

  LogicalResult matchAndRewrite(
      CallOp callOp, OpAdaptor adaptor,
      ConversionPatternRewriter& rewriter) const override {
    if (!callOp.getCallee().contains(kManualComputationBodyFuncName)) {
      return failure();
    }

    // NOTE: if the original `ManualComputationOp` had no operands (results),
    // then a @GlobalToLocalShape (@LocalToGlobalShape) custom call won't be
    // present. So we have to take the operands/results of the newly created
    // `ManualComputationOp` differently depending on whether the original had
    // operands/results.
    CustomCallOp globalToLocalShape;
    ValueRange operands = callOp->getOperands();
    if (!operands.empty()) {
      // An input to `sdy.manual_computation` can have a dimension of size 0
      // (i.e. 0 num-elements), in which case, the corresponding result of
      // `GlobalToLocalShape` custom call would be replaced with a constant of
      // the same shape. Therefore, we skip such operands until we find the
      // first one that is produced by the custom call.
      auto customCallResIt = llvm::find_if(operands, [](Value operand) {
        return operand.getDefiningOp<CustomCallOp>();
      });
      assert(customCallResIt != operands.end());
      globalToLocalShape = (*customCallResIt).getDefiningOp<CustomCallOp>();
      assert(globalToLocalShape.getCallTargetName() ==
             kGlobalToLocalShapeCallTargetName);
      operands = globalToLocalShape->getOperands();
    }
    TypeRange resultTypes = callOp->getResultTypes();
    CustomCallOp localToGlobalShape;
    if (!resultTypes.empty()) {
      assert(
          callOp->getResult(0).hasOneUse() &&
          "all CallOp results should be used by a single LocalToGlobalShape");
      localToGlobalShape =
          cast<CustomCallOp>(*callOp->getResult(0).getUsers().begin());
      resultTypes = localToGlobalShape->getResultTypes();
      assert(localToGlobalShape.getCallTargetName() ==
             kLocalToGlobalShapeCallTargetName);
    }

    auto shmapBodyFunc = symbolTable.lookup<FuncOp>(callOp.getCallee());
    if (shmapBodyFunc.empty()) {
      return callOp->emitOpError(
          "expected a unique FuncOp per "
          "@xla.sdy.manual_computation_body call. Were "
          "functions maybe somehow shared/de-duped between "
          "two ManualComputations?");
    }

    DictionaryAttr frontendAttrs = getFrontendAttrs(callOp);
    assert(frontendAttrs &&
           "Expected in/out shardings and manual axes as frontend attrs on the "
           "CallOp during round tripping.");
    auto manualComputationOp = rewriter.replaceOpWithNewOp<ManualComputationOp>(
        callOp, resultTypes, operands,
        parseStringAttr<TensorShardingPerValueAttr>(frontendAttrs,
                                                    kInShardings),
        parseStringAttr<TensorShardingPerValueAttr>(frontendAttrs,
                                                    kOutShardings),
        parseStringAttr<ManualAxesAttr>(frontendAttrs, kManualAxes));
    inlineRegionAndConvertTerminatorOp<ReturnOp>(
        shmapBodyFunc.getBody(), manualComputationOp.getRegion(), rewriter);
    rewriter.eraseOp(shmapBodyFunc);
    if (globalToLocalShape) {
      rewriter.eraseOp(globalToLocalShape);
    }
    if (localToGlobalShape) {
      rewriter.replaceOp(localToGlobalShape, manualComputationOp->getResults());
    }
    return success();
  }

 private:
  const SymbolTable& symbolTable;
};

class SdyRoundTripShardMapImportPass
    : public PassWrapper<SdyRoundTripShardMapImportPass,
                         OperationPass<ModuleOp>> {
 public:
  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(SdyRoundTripShardMapImportPass)

 private:
  void runOnOperation() final {
    ModuleOp module = getOperation();
    SymbolTableCollection symbolTableCollection;
    SymbolTable& symbolTable = symbolTableCollection.getSymbolTable(module);
    MLIRContext& context = getContext();
    ConversionTarget target(context);
    target.addDynamicallyLegalOp<CallOp>([](CallOp op) {
      return !op.getCallee().contains(kManualComputationBodyFuncName);
    });
    target.addLegalOp<ManualComputationOp, ReturnOp, CustomCallOp>();
    RewritePatternSet patterns(&context);
    patterns.add<ManualComputationPattern>(&context, symbolTable);
    if (failed(applyPartialConversion(module, target, std::move(patterns)))) {
      signalPassFailure();
    }
  }

  StringRef getArgument() const override {
    return "sdy-round-trip-shard-map-import";
  }

  StringRef getDescription() const override {
    return "converts a CallOp calling a @xla.sdy.manual_computation_body func "
           "with in/out shardings and manual axes as frontend attrs, wrapped "
           "with a pair of `CustomCallOps` that change the shape of the "
           "arguments/results, to a ManualComputationOp";
  }
  void getDependentDialects(DialectRegistry& registry) const final {
    registry.insert<SdyDialect>();
  }
};

}  // namespace

void registerSdyRoundTripShardMapImportPass() {
  registerPass(createSdyRoundTripShardMapImportPass);
}

std::unique_ptr<Pass> createSdyRoundTripShardMapImportPass() {
  return std::make_unique<SdyRoundTripShardMapImportPass>();
}

}  // namespace sdy
}  // namespace mlir
