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

#include <cassert>
#include <memory>  // IWYU pragma: keep

#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/Pass/Pass.h"  // IWYU pragma: keep
#include "shardy/dialect/sdy/ir/dialect.h"
#include "shardy/dialect/sdy/ir/utils.h"  // IWYU pragma: keep
#include "shardy/dialect/sdy/transforms/common/sharding_walker.h"

namespace mlir {
namespace sdy {

#define GEN_PASS_DEF_CLOSESHARDINGSPASS
#include "shardy/dialect/sdy/transforms/export/passes.h.inc"

namespace {

struct CloseShardingsPass
    : public impl::CloseShardingsPassBase<CloseShardingsPass> {
  using CloseShardingsPassBase::CloseShardingsPassBase;

  void runOnOperation() final {
    transformShardings(getOperation(), TensorShardingAttr::getClosedLike);
  }
};

}  // namespace

}  // namespace sdy
}  // namespace mlir