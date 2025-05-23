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

#ifndef SDY_CANONICALIZATION
#define SDY_CANONICALIZATION

include "shardy/dialect/sdy/ir/ops.td"
include "mlir/IR/PatternBase.td"

def HasOneUse: Constraint<CPred<"$_self.hasOneUse()">, "has one use">;

def TensorShardingEquivalent : Constraint<CPred<
    "getSharding($0).areDimAxesEqual($1) && getSharding($0).getMeshOrRef() == $1.getMeshOrRef()">,
    "tensor sharding equivalent">;

def ReshardOfReshardPattern :
    Pat<(Sdy_ReshardOp (Sdy_ReshardOp:$inner_reshard $tensor, $inner_sharding), $outer_sharding),
        (Sdy_ReshardOp $tensor, $outer_sharding), [(HasOneUse:$inner_reshard)]>;

// TODO(b/390759740): Add more patterns for collectives, e.g., all-gather of
// all-slice with matching axes.

def AllGatherNoopPattern : Pat<(Sdy_AllGatherOp $tensor, Sdy_EmptyAxesPerDim:$gatheringAxes, $outSharding),
                               (replaceWithValue $tensor)>;

def AllSliceNoopPattern : Pat<(Sdy_AllSliceOp $tensor, Sdy_EmptyAxesPerDim:$slicingAxes, $outSharding),
                               (replaceWithValue $tensor)>;

// TODO(b/410842735): Add patterns for all-to-all params with empty axes.

def AllReduceNoopPattern : Pat<(Sdy_AllReduceOp $tensor, Sdy_EmptyAxisList:$reductionAxes, $resultSharding),
                               (replaceWithValue $tensor)>;

def CollectivePermuteNoopPattern : Pat<
  (Sdy_CollectivePermuteOp $tensor, $out_sharding),
  (replaceWithValue $tensor),
  [(TensorShardingEquivalent $tensor, $out_sharding)]>;

def AllSliceOfAllGatherPattern : Pat<
  (Sdy_AllSliceOp (Sdy_AllGatherOp $tensor, $gatheringAxes, $_), $slicingAxes, $_),
  (replaceWithValue $tensor),
  [(Constraint<AllMatchPred<["gatheringAxes", "slicingAxes"]>, "axes match">)]>;

def AllToAllParamsNoOverlap: Constraint<CPred<"!$0.overlaps($1)">, "no overlap">;

def CombineAllToAllParams: NativeCodeCall<"$0.combineAndSort($1)">;

def AllToAllNoUsePattern : Pat<
  (Sdy_AllToAllOp:$all_to_all $tensor, $params, $sharding),
  (replaceWithValue $tensor),
  [(HasNoUseOf: $all_to_all)]>;

def AllToAllFusionPattern : Pat<
  (Sdy_AllToAllOp
    (Sdy_AllToAllOp:$inner_all_to_all $inner_tensor, $inner_params, $inner_sharding),
    $outer_params, $outer_sharding),
  (Sdy_AllToAllOp $inner_tensor, (CombineAllToAllParams $inner_params, $outer_params),
                  $outer_sharding),
  [(HasOneUse:$inner_all_to_all), (AllToAllParamsNoOverlap $inner_params, $outer_params)]>;

#endif  // SDY_CANONICALIZATION
