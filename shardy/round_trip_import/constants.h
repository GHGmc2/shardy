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

#ifndef SHARDY_ROUND_TRIP_IMPORT_CONSTANTS_H_
#define SHARDY_ROUND_TRIP_IMPORT_CONSTANTS_H_

#include "llvm/ADT/StringRef.h"

namespace mlir {
namespace sdy {

// The attribute name for xla::HloSharding.
inline constexpr llvm::StringRef kXlaShardingAttr = "mhlo.sharding";

// The target name of the Sharding custom call.
inline constexpr llvm::StringRef kShardingCustomCallTargetName = "Sharding";

// The target name of the Python CPU callback custom call.
inline constexpr llvm::StringRef kPythonCpuCallbackCustomCallTargetName =
    "xla_python_cpu_callback";

// The target name of the FFI Python CPU callback custom call.
inline constexpr llvm::StringRef kFFIPythonCpuCallbackCustomCallTargetName =
    "xla_ffi_python_cpu_callback";

// The target name of the Python GPU callback custom call.
inline constexpr llvm::StringRef kPythonGpuCallbackCustomCallTargetName =
    "xla_python_gpu_callback";

// The target name of the FFI Python GPU callback custom call.
inline constexpr llvm::StringRef kFFIPythonGpuCallbackCustomCallTargetName =
    "xla_ffi_python_gpu_callback";

// The attribute name for backend config.
inline constexpr llvm::StringRef kXlaBackendConfigAttr = "backend_config";

// The attribute name for inlineable.
inline constexpr llvm::StringRef kXlaInlineableAttr = "inlineable";

// Attribute name for temporarily storing the Shardy sharding during HLO
// sdy-round-trip. It cannot match the name `kShardingAttr` ("sdy.sharding"), as
// during sdy-round-trip, going from HLO to StableHLO, the code removes
// attributes in the `frontend_attributes` field, making them top level. And
// Shardy verification expects `kShardingAttr` to be of type
// TensorShardingAttr/TensorShardingPerValueAttr - not a StringAttr.
inline constexpr llvm::StringRef kShardingRoundTripAttr = "xla.sdy.sharding";

// Attribute name for temporarily storing the Shardy sharding rule during HLO
// sdy-round-trip. It cannot match the name `kShardingRuleAttr`
// ("sdy.sharding_rule"), as during sdy-round-trip, going from HLO to StableHLO,
// the code removes attributes in the `frontend_attributes` field, making them
// top level. And Shardy verification expects `kShardingRuleAttr` to be of type
// OpShardingRuleAttr - not a StringAttr.
inline constexpr llvm::StringRef kShardingRuleRoundTripAttr =
    "xla.sdy.sharding_rule";

// Attribute name for temporarily storing the Shardonnay meshes during HLO
// round-trip.
inline constexpr llvm::StringRef kMeshesRoundTripAttr = "xla.sdy.meshes";

// The target name of the custom call when round tripping during HLO
// round-trip.
inline constexpr llvm::StringRef kFuncResultShardingTargetName =
    "xla.sdy.FuncResultSharding";

// The target name of the ShardingGroup custom call.
inline constexpr llvm::StringRef kShardingGroupCustomCallTargetName =
    "xla.sdy.ShardingGroup";

// Sharding group id attribute name. The attribute will be of type `int64_t`
// and will be used to identify a group of ops that should be sharded together.
inline constexpr llvm::StringRef kShardingGroupIdAttr =
    "xla.sdy.sharding_group_id";

// Attribute name for storing frontend attributes in XLA.
inline constexpr llvm::StringRef kFrontendAttributesAttr =
    "mhlo.frontend_attributes";

// Attribute name for the in shardings of a `ManualComputationOp`.
inline constexpr llvm::StringRef kInShardings = "xla.sdy.in_shardings";

// Attribute name for the out shardings of a `ManualComputationOp`.
inline constexpr llvm::StringRef kOutShardings = "xla.sdy.out_shardings";

// Attribute name for the manual axes of a `ManualComputationOp`.
inline constexpr llvm::StringRef kManualAxes = "xla.sdy.manual_axes";

// The function name of the of the body of a `ManualComputationOp` during Shardy
// round tripping. Used
inline constexpr llvm::StringRef kManualComputationBodyFuncName =
    "xla.sdy.manual_computation_body";

// The target name of the custom call that changes operands from global to local
// shape during Shardy round tripping.
inline constexpr llvm::StringRef kGlobalToLocalShapeCallTargetName =
    "xla.sdy.GlobalToLocalShape";

// The target name of the custom call that changes results from local to global
// shape during Shardy round tripping.
inline constexpr llvm::StringRef kLocalToGlobalShapeCallTargetName =
    "xla.sdy.LocalToGlobalShape";

}  // namespace sdy
}  // namespace mlir

#endif  // SHARDY_ROUND_TRIP_IMPORT_CONSTANTS_H_
