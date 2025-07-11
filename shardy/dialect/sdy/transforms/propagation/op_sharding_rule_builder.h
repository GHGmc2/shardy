/* Copyright 2024 The Shardy Authors.

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

#ifndef SHARDY_DIALECT_SDY_TRANSFORMS_PROPAGATION_OP_SHARDING_RULE_BUILDER_H_
#define SHARDY_DIALECT_SDY_TRANSFORMS_PROPAGATION_OP_SHARDING_RULE_BUILDER_H_

#include <cassert>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <optional>

#include "mlir/IR/BuiltinTypeInterfaces.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/Operation.h"
#include "mlir/IR/TypeRange.h"
#include "mlir/Support/LLVM.h"
#include "shardy/dialect/sdy/ir/dialect.h"
#include "shardy/dialect/sdy/ir/enums.h"

namespace mlir {
namespace sdy {

// Represents a null dimension to indicate that a tensor shouldn't be mapped to
// a certain factor.
const int kNullDim = -1;

// The factor mappings that compose a dimension of a tensor.
struct DimMapping {
  SmallVector<int64_t> factorIndices;
};

// A list of mappings per dimension.
using TensorMapping = SmallVector<DimMapping>;

// A builder that helps incrementally create an `OpShardingRuleAttr`. See the
// definition of `OpShardingRule` for what it does/specifies.
class OpShardingRuleBuilder {
 public:
  explicit OpShardingRuleBuilder(
      TypeRange operandTypes, TypeRange resultTypes, MLIRContext* context,
      std::optional<int64_t> reserveNumFactors = std::nullopt);

  explicit OpShardingRuleBuilder(
      Operation* op, std::optional<int64_t> reserveNumFactors = std::nullopt);

  // Builds the `OpShardingRuleAttr`.
  //
  // Since all dimensions must have at least one factor, this method will add a
  // factor of size 1 to all dimensions that don't have a factor. This is done
  // in place for `factorSizes`, hence this method is not const, however the
  // additional factor sizes are removed after `OpShardingRuleAttr` is created,
  // so the builder is unchanged.
  OpShardingRuleAttr build();

  // Generic builder for any pointwise op (e.g. tanh, add, and, ceiling, etc.)
  static OpShardingRuleAttr buildPointwise(Operation* op);

  // Adds a new factor of size `factorSize` and type `factorType`, and maps it
  // to the corresponding dimension of each operand/result as specified by
  // `operandDims` and `resultDims`.
  //
  // If `isBlocked` is true, the factor will be marked as blocked, i.e., Shardy
  // will not propagate shardings along this factor.
  //
  // Skips operands and results with corresponding dimension `kNullDim`.
  OpShardingRuleBuilder& addFactor(
      ArrayRef<int64_t> operandDims, ArrayRef<int64_t> resultDims,
      int64_t factorSize, FactorType factorType = FactorType::kPassThrough,
      bool isBlocked = false);

  // Same as addFactor above, but updates the same dimension for all
  // operands that have rank at least 1.
  OpShardingRuleBuilder& addFactorSameForAllOperands(
      int64_t operandDim, int64_t factorSize,
      FactorType factorType = FactorType::kPassThrough, bool isBlocked = false);

  // Same as addFactor above, but updates the same dimension for all
  // results that have rank at least 1.
  OpShardingRuleBuilder& addFactorSameForAllResults(
      int64_t resultDim, int64_t factorSize,
      FactorType factorType = FactorType::kPassThrough, bool isBlocked = false);

  // Same as addFactor above, but updates the same dimension for all operands
  // and results that have rank at least 1.
  //
  // Useful when creating rules for pointwise ops.
  OpShardingRuleBuilder& addFactor(
      int64_t dim, int64_t factorSize,
      FactorType factorType = FactorType::kPassThrough, bool isBlocked = false);

  // Adds a pointwise factor for all dimensions of all operands/results that
  // have rank at least 1. The factor type is determined by `getFactorType`.
  OpShardingRuleBuilder& addPointwise(
      ArrayRef<int64_t> shape,
      std::function<FactorType(int64_t)> getFactorType =
          [](int64_t) { return FactorType::kPassThrough; },
      bool isBlocked = false);

  // Overload to be able to provide conditional blocking.
  OpShardingRuleBuilder& addPointwise(
      ArrayRef<int64_t> shape,
      std::function<FactorType(int64_t)> getFactorType,
      std::function<bool(FactorType)> getIsBlocked);

  // Adds a pointwise factor for all dimensions that satisfy `pred` of all
  // operands/results that have rank at least 1. The factor type is determined
  // by `getFactorType`.
  OpShardingRuleBuilder& addPointwiseIf(
      ArrayRef<int64_t> shape, std::function<bool(int64_t)> pred,
      std::function<FactorType(int64_t)> getFactorType = [](int64_t) {
        return FactorType::kPassThrough;
      });

  // Adds a pointwise factor for all dimensions of all operands/results that
  // have rank at least 1.
  //
  // Each dimension whose size in `inShape` and `outShape` is different, gets a
  // `mismatchFactorType` factor type and is marked as blocked if
  // `mismatchFactorIsBlocked` is true.
  OpShardingRuleBuilder& addPointwiseWithDiffTypeForMismatch(
      ArrayRef<int64_t> inShape, ArrayRef<int64_t> outShape,
      FactorType mismatchFactorType = FactorType::kNeedReplication,
      bool mismatchFactorIsBlocked = false);

 private:
  int64_t reserveFactor(int64_t factorSize, FactorType factorType,
                        bool isBlocked);

  MLIRContext* context;
  SmallVector<int64_t> factorSizes;
  // The mappings of factor sizes for each operand/result. Specify the index of
  // the factor, with its corresponding size stored in `factorSizes`.
  SmallVector<TensorMapping> operandMappings;
  SmallVector<TensorMapping> resultMappings;

  SmallVector<int64_t> reductionFactors, needReplicationFactors,
      permutationFactors;

  SmallVector<int64_t> blockedPropagationFactors;
};

// Creates an identity mapping for an op with `numOperands` operands and
// `numResults` results, all with tensors of type `type`.
//
// Think of this as a pointwise op like add, but with many operands/results,
// i.e., all operands/results have the same mapping.
//
// NOTE: an empty rule {([])->([])} will be created for scalar ops.
OpShardingRuleAttr createIdentityShardingRule(ShapedType type,
                                              size_t numOperands = 1,
                                              size_t numResults = 1);

}  // namespace sdy
}  // namespace mlir

#endif  // SHARDY_DIALECT_SDY_TRANSFORMS_PROPAGATION_OP_SHARDING_RULE_BUILDER_H_
