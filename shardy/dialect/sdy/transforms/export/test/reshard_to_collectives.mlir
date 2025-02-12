// RUN: sdy_opt %s -sdy-reshard-to-collectives | FileCheck %s

sdy.mesh @mesh1d_6 = <["x"=6]>
sdy.mesh @mesh2d = <["x"=2, "y"=2]>
sdy.mesh @mesh2d_4x2 = <["x"=4, "y"=2]>
sdy.mesh @mesh2d_2x8 = <["x"=2, "y"=8]>
sdy.mesh @mesh2d_2x3 = <["x"=2, "y"=3]>
sdy.mesh @mesh3d = <["x"=2, "y"=2, "z"=2]>
sdy.mesh @mesh3d_4x2x4 = <["x"=4, "y"=2, "z"=4]>
sdy.mesh @mesh4d = <["x"=2, "y"=2, "z"=2, "w"=2]>
sdy.mesh @mesh4d_z4 = <["x"=2, "y"=2, "z"=4, "w"=2]>
sdy.mesh @mesh4d_w4 = <["x"=2, "y"=2, "z"=2, "w"=4]>
sdy.mesh @mesh4d_w16 = <["x"=2, "y"=2, "z"=2, "w"=16]>
sdy.mesh @mesh6d = <["x"=2, "y"=2, "z"=2, "w"=2, "u"=2, "v"=2]>

// CHECK-LABEL: func @redundant_reshard
func.func @redundant_reshard(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh2d, [{"x"}, {"y"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: return %arg0
  %0 = sdy.reshard %arg0 <@mesh2d, [{"x", ?}, {"y", ?}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @all_gather_single_axis
func.func @all_gather_single_axis(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh2d, [{"y"}, {"x"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: sdy.all_gather [{}, {"x"}] %arg0 out_sharding=<@mesh2d, [{"y"}, {}]>
  %0 = sdy.reshard %arg0 <@mesh2d, [{"y"}, {}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @all_gather_multiple_axes
func.func @all_gather_multiple_axes(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d, [{"x", "y", "z"}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: sdy.all_gather [{"y", "z"}, {}] %arg0 out_sharding=<@mesh3d, [{"x"}, {}]>
  %0 = sdy.reshard %arg0 <@mesh3d, [{"x"}, {}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @all_gather_multiple_dims
func.func @all_gather_multiple_dims(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d, [{"y", "z"}, {"x"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: sdy.all_gather [{"z"}, {}] %arg0 out_sharding=<@mesh3d, [{"y"}, {"x"}]>
  %0 = sdy.reshard %arg0 <@mesh3d, [{"y"}, {"x"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @all_gather_with_subaxis
func.func @all_gather_with_subaxis(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh2d_2x8, [{"y"}, {"x"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: sdy.all_gather [{"y":(4)2}, {}] %arg0 out_sharding=<@mesh2d_2x8, [{"y":(1)4}, {"x"}]>
 %0 = sdy.reshard %arg0 <@mesh2d_2x8, [{"y":(1)4}, {"x"}]> :  tensor<16x8xf32>
 return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @all_slice_multiple_axes
func.func @all_slice_multiple_axes(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d, [{}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: sdy.all_slice [{"x"}, {"y", "z"}] %arg0 out_sharding=<@mesh3d, [{"x"}, {"y", "z"}]>
  %0 = sdy.reshard %arg0 <@mesh3d, [{"x"}, {"y", "z"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @all_slice_minor_axis
func.func @all_slice_minor_axis(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d, [{"x"}, {"y"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: sdy.all_slice [{}, {"z"}] %arg0 out_sharding=<@mesh3d, [{"x"}, {"y", "z"}]>
  %0 = sdy.reshard %arg0 <@mesh3d, [{"x"}, {"y", "z"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @all_slice_with_subaxis
func.func @all_slice_with_subaxis(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{"x":(1)2}, {"y"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: sdy.all_slice [{"x":(2)2}, {"z":(1)2}] %arg0 out_sharding=<@mesh3d_4x2x4, [{"x"}, {"y", "z":(1)2}]>
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"x"}, {"y", "z":(1)2}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @all_to_all_single_axis
func.func @all_to_all_single_axis(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d, [{"x"}, {"y"}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: sdy.all_to_all {"x"} 0->2 %arg0 out_sharding=<@mesh3d, [{}, {"y"}, {"x"}]>
  %0 = sdy.reshard %arg0 <@mesh3d, [{}, {"y"}, {"x"}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @all_to_all_multiple_axes
func.func @all_to_all_multiple_axes(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d, [{"x"}, {}, {"y", "z"}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: sdy.all_to_all {"y", "z"} 2->1 %arg0 out_sharding=<@mesh3d, [{"x"}, {"y", "z"}, {}]>
  %0 = sdy.reshard %arg0 <@mesh3d, [{"x"}, {"y", "z"}, {}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @two_all_to_alls_different_tgt_dims
func.func @two_all_to_alls_different_tgt_dims(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{}, {"y", "x"}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: %[[ALL_TO_ALL_0:.*]] = sdy.all_to_all {"x"} 1->0 %arg0 out_sharding=<@mesh3d_4x2x4, [{"x"}, {"y"}, {}]>
  // CHECK-NEXT: %[[ALL_TO_ALL_1:.*]] = sdy.all_to_all {"y"} 1->2 %[[ALL_TO_ALL_0]] out_sharding=<@mesh3d_4x2x4, [{"x"}, {}, {"y"}]>
  // CHECK-NEXT: return %[[ALL_TO_ALL_1]]
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"x"}, {}, {"y"}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @two_all_to_alls_tgt_dim_not_empty
func.func @two_all_to_alls_tgt_dim_not_empty(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{"x"}, {"y", "z"}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: %[[ALL_TO_ALL_0:.*]] = sdy.all_to_all {"z"} 1->0 %arg0 out_sharding=<@mesh3d_4x2x4, [{"x", "z"}, {"y"}, {}]>
  // CHECK-NEXT: %[[ALL_TO_ALL_1:.*]] = sdy.all_to_all {"y"} 1->2 %[[ALL_TO_ALL_0]] out_sharding=<@mesh3d_4x2x4, [{"x", "z"}, {}, {"y"}]>
  // CHECK-NEXT: return %[[ALL_TO_ALL_1]]
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"x", "z"}, {}, {"y"}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @slice_then_all_to_alls
func.func @slice_then_all_to_alls(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{}, {"y", "z"}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{"x"}, {}, {}] %arg0 out_sharding=<@mesh3d_4x2x4, [{"x"}, {"y", "z"}, {}]>
  // CHECK-NEXT: %[[ALL_TO_ALL_0:.*]] = sdy.all_to_all {"z"} 1->0 %[[ALL_SLICE]] out_sharding=<@mesh3d_4x2x4, [{"x", "z"}, {"y"}, {}]>
  // CHECK-NEXT: %[[ALL_TO_ALL_1:.*]] = sdy.all_to_all {"y"} 1->2 %[[ALL_TO_ALL_0]] out_sharding=<@mesh3d_4x2x4, [{"x", "z"}, {}, {"y"}]>
  // CHECK-NEXT: return %[[ALL_TO_ALL_1]]
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"x", "z"}, {}, {"y"}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @all_to_all_subaxis_then_all_gather
func.func @all_to_all_subaxis_then_all_gather(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{"x"}, {"z", "y"}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: %[[ALL_TO_ALL_0:.*]] = sdy.all_to_all {"y"} 1->2 %arg0 out_sharding=<@mesh3d_4x2x4, [{"x"}, {"z"}, {"y"}]>
  // CHECK-NEXT: %[[ALL_TO_ALL_1:.*]] = sdy.all_to_all {"z":(2)2} 1->0 %[[ALL_TO_ALL_0]] out_sharding=<@mesh3d_4x2x4, [{"x", "z":(2)2}, {"z":(1)2}, {"y"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{}, {"z":(1)2}, {}] %[[ALL_TO_ALL_1]] out_sharding=<@mesh3d_4x2x4, [{"x", "z":(2)2}, {}, {"y"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"x", "z":(2)2}, {}, {"y"}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @all_to_all_subaxis_and_full_axis_then_all_gather
func.func @all_to_all_subaxis_and_full_axis_then_all_gather(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh4d_z4, [{"x"}, {"z", "w", "y"}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: %[[ALL_TO_ALL_0:.*]] = sdy.all_to_all {"y"} 1->2 %arg0 out_sharding=<@mesh4d_z4, [{"x"}, {"z", "w"}, {"y"}]>
  // CHECK-NEXT: %[[ALL_TO_ALL_1:.*]] = sdy.all_to_all {"z":(2)2, "w"} 1->0 %[[ALL_TO_ALL_0]] out_sharding=<@mesh4d_z4, [{"x", "z":(2)2, "w"}, {"z":(1)2}, {"y"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{}, {"z":(1)2}, {}] %[[ALL_TO_ALL_1]] out_sharding=<@mesh4d_z4, [{"x", "z":(2)2, "w"}, {}, {"y"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh4d_z4, [{"x", "z":(2)2, "w"}, {}, {"y"}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// TODO(b/394758885): All-slice at source dimension of all-to-all if it can
// avoid a redundant collective permute

// CHECK-LABEL: func @slice_on_src_dim_then_all_to_all_subaxis
func.func @slice_on_src_dim_then_all_to_all_subaxis(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh4d_w4, [{}, {"w":(1)2}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{"w":(2)2}, {}, {}] %arg0 out_sharding=<@mesh4d_w4, [{"w":(2)2}, {"w":(1)2}, {}]>
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %[[ALL_SLICE]] out_sharding=<@mesh4d_w4, [{"w":(1)2}, {"w":(2)2}, {}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"w":(2)2} 1->0 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh4d_w4, [{"w"}, {}, {}]>
  // CHECK-NEXT: return %[[ALL_TO_ALL]]
  %0 = sdy.reshard %arg0 <@mesh4d_w4, [{"w"}, {}, {}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @slice_on_src_dim_then_all_to_all_multiple_axes
func.func @slice_on_src_dim_then_all_to_all_multiple_axes(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh4d_w4, [{}, {"x"}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{}, {}, {"y", "z"}] %arg0 out_sharding=<@mesh4d_w4, [{}, {"x"}, {"y", "z"}]>
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %[[ALL_SLICE]] out_sharding=<@mesh4d_w4, [{}, {"z"}, {"x", "y"}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"z"} 1->2 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh4d_w4, [{}, {}, {"x", "y", "z"}]>
  // CHECK-NEXT: return %[[ALL_TO_ALL]]
  %0 = sdy.reshard %arg0 <@mesh4d_w4, [{}, {}, {"x", "y", "z"}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @replace_same_size_axes_same_dim
func.func @replace_same_size_axes_same_dim(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d, [{"z"}, {"y"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh3d, [{"z"}, {"x"}]>
  // CHECK-NEXT: return %[[COLLECTIVE_PERMUTE]]
  %0 = sdy.reshard %arg0 <@mesh3d, [{"z"}, {"x"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @replace_smaller_axis_with_bigger_same_dim
func.func @replace_smaller_axis_with_bigger_same_dim(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{"z"}, {"y"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{}, {"x":(1)2}] %arg0 out_sharding=<@mesh3d_4x2x4, [{"z"}, {"y", "x":(1)2}]>
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %[[ALL_SLICE]] out_sharding=<@mesh3d_4x2x4, [{"z"}, {"x"}]>
  // CHECK-NEXT: return %[[COLLECTIVE_PERMUTE]]
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"z"}, {"x"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @replace_bigger_axis_with_smaller_same_dim
func.func @replace_bigger_axis_with_smaller_same_dim(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{"z"}, {"x"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh3d_4x2x4, [{"z"}, {"y", "x":(1)2}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{}, {"x":(1)2}] %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh3d_4x2x4, [{"z"}, {"y"}]
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"z"}, {"y"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @replace_major_most_axis_in_dim
func.func @replace_major_most_axis_in_dim(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh4d, [{"x", "y", "z"}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh4d, [{"w", "y", "z"}, {}]>
  // CHECK-NEXT: return %[[COLLECTIVE_PERMUTE]]
  %0 = sdy.reshard %arg0 <@mesh4d, [{"w", "y", "z"}, {}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @replace_same_size_axes_diff_dims
func.func @replace_same_size_axes_diff_dims(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh2d, [{"x"}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{}, {"y"}] %arg0 out_sharding=<@mesh2d, [{"x"}, {"y"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"x"}, {}] %[[ALL_SLICE]] out_sharding=<@mesh2d, [{}, {"y"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh2d, [{}, {"y"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @replace_bigger_axis_with_smaller_diff_dims
func.func @replace_bigger_axis_with_smaller_diff_dims(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh2d_4x2, [{"x"}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{}, {"y"}] %arg0 out_sharding=<@mesh2d_4x2, [{"x"}, {"y"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"x"}, {}] %[[ALL_SLICE]] out_sharding=<@mesh2d_4x2, [{}, {"y"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh2d_4x2, [{}, {"y"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @replace_multiple_axes_diff_dims
func.func @replace_multiple_axes_diff_dims(%arg0 : tensor<8x8x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh6d, [{"x"}, {"y", "z"}, {}, {}]>}) -> tensor<8x8x8x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{}, {}, {"w", "u"}, {"v"}] %arg0 out_sharding=<@mesh6d, [{"x"}, {"y", "z"}, {"w", "u"}, {"v"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"x"}, {"y", "z"}, {}, {}] %[[ALL_SLICE]] out_sharding=<@mesh6d, [{}, {}, {"w", "u"}, {"v"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh6d, [{}, {}, {"w", "u"}, {"v"}]> : tensor<8x8x8x8xf32>
  return %0 : tensor<8x8x8x8xf32>
}

// CHECK-LABEL: func @replace_smaller_axis_with_bigger_diff_dims
func.func @replace_smaller_axis_with_bigger_diff_dims(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh2d_4x2, [{"y"}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{}, {"x"}] %arg0 out_sharding=<@mesh2d_4x2, [{"y"}, {"x"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"y"}, {}] %[[ALL_SLICE]] out_sharding=<@mesh2d_4x2, [{}, {"x"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh2d_4x2, [{}, {"x"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @slice_tgt_dim_then_all_to_all_then_all_gather
func.func @slice_tgt_dim_then_all_to_all_then_all_gather(%arg0: tensor<16x8xf32> {sdy.sharding = #sdy.sharding<@mesh4d_w4, [{"y", "z", "w"}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{}, {"x"}] %arg0 out_sharding=<@mesh4d_w4, [{"y", "z", "w"}, {"x"}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"w"} 0->1 %[[ALL_SLICE]] out_sharding=<@mesh4d_w4, [{"y", "z"}, {"x", "w"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"z"}, {}] %[[ALL_TO_ALL]] out_sharding=<@mesh4d_w4, [{"y"}, {"x", "w"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh4d_w4, [{"y"}, {"x", "w"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @swap_same_size_axes_between_dims
func.func @swap_same_size_axes_between_dims(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh2d, [{"x"}, {"y"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh2d, [{"y"}, {"x"}]>
  // CHECK-NEXT: return %[[COLLECTIVE_PERMUTE]]
  %0 = sdy.reshard %arg0 <@mesh2d, [{"y"}, {"x"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @swap_diff_size_axes_between_dims
func.func @swap_diff_size_axes_between_dims(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh2d_4x2, [{"x"}, {"y"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh2d_4x2, [{"y", "x":(2)2}, {"x":(1)2}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"x":(2)2} 0->1 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh2d_4x2, [{"y"}, {"x"}]>
  // CHECK-NEXT: return %[[ALL_TO_ALL]]
  %0 = sdy.reshard %arg0 <@mesh2d_4x2, [{"y"}, {"x"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @slice_and_swap_axes_between_dims
func.func @slice_and_swap_axes_between_dims(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d, [{"x"}, {"y"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{"z"}, {}] %arg0 out_sharding=<@mesh3d, [{"x", "z"}, {"y"}]>
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %[[ALL_SLICE]] out_sharding=<@mesh3d, [{"x", "y"}, {"z"}]>
  // CHECK-NEXT: return %[[COLLECTIVE_PERMUTE]]
  %0 = sdy.reshard %arg0 <@mesh3d, [{"x", "y"}, {"z"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @slice_sub_axes_then_swap_between_dims
func.func @slice_sub_axes_then_swap_between_dims(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{"z"}, {"y"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{"x":(2)2}, {"x":(1)2}] %arg0 out_sharding=<@mesh3d_4x2x4, [{"z", "x":(2)2}, {"y", "x":(1)2}]>
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %[[ALL_SLICE]] out_sharding=<@mesh3d_4x2x4, [{"y", "z"}, {"x"}]>
  // CHECK-NEXT: return %[[COLLECTIVE_PERMUTE]]
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"y", "z"}, {"x"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @swap_sub_axes_then_all_to_all_and_all_gather
func.func @swap_sub_axes_then_all_to_all_and_all_gather(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{"z", "y"}, {"x"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh3d_4x2x4, [{"x", "z":(1)2}, {"y", "z":(2)2}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"z":(2)2} 1->0 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh3d_4x2x4, [{"x", "z"}, {"y"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{}, {"y"}] %[[ALL_TO_ALL]] out_sharding=<@mesh3d_4x2x4, [{"x", "z"}, {}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"x", "z"}, {}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @reorder_axes_single_dim
func.func @reorder_axes_single_dim(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{"x", "y"}, {"z"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh3d_4x2x4, [{"y", "x"}, {"z"}]>
  // CHECK-NEXT: return %[[COLLECTIVE_PERMUTE]]
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"y", "x"}, {"z"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @reorder_axes_across_dims
func.func @reorder_axes_across_dims(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{"x", "y"}, {"z"}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh3d_4x2x4, [{"y", "z"}, {"x"}]>
  // CHECK-NEXT: return %[[COLLECTIVE_PERMUTE]]
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"y", "z"}, {"x"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @slice_then_reorder_axes
func.func @slice_then_reorder_axes(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh2d, [{"y"}, {}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{"x"}, {}, {}] %arg0 out_sharding=<@mesh2d, [{"y", "x"}, {}, {}]>
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %[[ALL_SLICE]] out_sharding=<@mesh2d, [{"x", "y"}, {}, {}]>
  // CHECK-NEXT: return %[[COLLECTIVE_PERMUTE]]
  %0 = sdy.reshard %arg0 <@mesh2d, [{"x", "y"}, {}, {}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @reorder_axes_for_all_gather
func.func @reorder_axes_for_all_gather(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d, [{"y", "x", "z"}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh3d, [{"z", "y", "x"}, {}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"y", "x"}, {}] %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh3d, [{"z"}, {}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh3d, [{"z"}, {}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @reorder_axes_for_all_to_all_then_all_gather_single_axis
func.func @reorder_axes_for_all_to_all_then_all_gather_single_axis(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d, [{"y", "x", "z"}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh3d, [{"z", "x", "y"}, {}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"y"} 0->1 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh3d, [{"z", "x"}, {"y"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"x"}, {}] %[[ALL_TO_ALL]] out_sharding=<@mesh3d, [{"z"}, {"y"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh3d, [{"z"}, {"y"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @reorder_axes_for_all_to_all_then_all_gather_remaining_axes
func.func @reorder_axes_for_all_to_all_then_all_gather_remaining_axes(%arg0 : tensor<16x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d, [{"z", "y", "x"}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh3d, [{"z", "x", "y"}, {}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"y"} 0->1 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh3d, [{"z", "x"}, {"y"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"z", "x"}, {}] %[[ALL_TO_ALL]] out_sharding=<@mesh3d, [{}, {"y"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh3d, [{}, {"y"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @all_to_all_axes_at_src_out_of_order
func.func @all_to_all_axes_at_src_out_of_order(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh2d, [{}, {"y", "x"}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh2d, [{}, {"x", "y"}, {}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"x", "y"} 1->0 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh2d, [{"x", "y"}, {}, {}]>
  // CHECK-NEXT: return %[[ALL_TO_ALL]]
  %0 = sdy.reshard %arg0 <@mesh2d, [{"x", "y"}, {}, {}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @all_to_all_axes_at_src_and_tgt_out_of_order
func.func @all_to_all_axes_at_src_and_tgt_out_of_order(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{"z"}, {"y", "x"}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh3d_4x2x4, [{"x"}, {"y", "z"}, {}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"y", "z"} 1->0 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh3d_4x2x4, [{"x", "y", "z"}, {}, {}]>
  // CHECK-NEXT: return %[[ALL_TO_ALL]]
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"x", "y", "z"}, {}, {}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @all_to_all_two_tgt_dims_src_out_of_order
func.func @all_to_all_two_tgt_dims_src_out_of_order(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{}, {"x", "z", "y"}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh3d_4x2x4, [{}, {"x", "y", "z"}, {}]>
  // CHECK-NEXT: %[[ALL_TO_ALL_0:.*]] = sdy.all_to_all {"z"} 1->2 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh3d_4x2x4, [{}, {"x", "y"}, {"z"}]>
  // CHECK-NEXT: %[[ALL_TO_ALL_1:.*]] = sdy.all_to_all {"x", "y"} 1->0 %[[ALL_TO_ALL_0]] out_sharding=<@mesh3d_4x2x4, [{"x", "y"}, {}, {"z"}]>
  // CHECK-NEXT: return %[[ALL_TO_ALL_1]]
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"x", "y"}, {}, {"z"}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @all_to_all_two_tgt_dims_src_out_of_order_2
func.func @all_to_all_two_tgt_dims_src_out_of_order_2(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh3d_4x2x4, [{}, {"y", "z", "x"}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh3d_4x2x4, [{}, {"x", "y", "z"}, {}]>
  // CHECK-NEXT: %[[ALL_TO_ALL_0:.*]] = sdy.all_to_all {"z"} 1->2 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh3d_4x2x4, [{}, {"x", "y"}, {"z"}]>
  // CHECK-NEXT: %[[ALL_TO_ALL_1:.*]] = sdy.all_to_all {"x", "y"} 1->0 %[[ALL_TO_ALL_0]] out_sharding=<@mesh3d_4x2x4, [{"x", "y"}, {}, {"z"}]>
  // CHECK-NEXT: return %[[ALL_TO_ALL_1]]
  %0 = sdy.reshard %arg0 <@mesh3d_4x2x4, [{"x", "y"}, {}, {"z"}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @all_to_all_and_gather_src_dim_out_of_order
func.func @all_to_all_and_gather_src_dim_out_of_order(%arg0 : tensor<16x8x8xf32> {sdy.sharding=#sdy.sharding<@mesh4d_z4, [{"x"}, {"y", "z", "w"}, {}]>}) -> tensor<16x8x8xf32> {
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %arg0 out_sharding=<@mesh4d_z4, [{"x"}, {"z", "w", "y"}, {}]>
  // CHECK-NEXT: %[[ALL_TO_ALL_0:.*]] = sdy.all_to_all {"y"} 1->2 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh4d_z4, [{"x"}, {"z", "w"}, {"y"}]>
  // CHECK-NEXT: %[[ALL_TO_ALL_1:.*]] = sdy.all_to_all {"z":(2)2, "w"} 1->0 %[[ALL_TO_ALL_0]] out_sharding=<@mesh4d_z4, [{"x", "z":(2)2, "w"}, {"z":(1)2}, {"y"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{}, {"z":(1)2}, {}] %[[ALL_TO_ALL_1]] out_sharding=<@mesh4d_z4, [{"x", "z":(2)2, "w"}, {}, {"y"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh4d_z4, [{"x", "z":(2)2, "w"}, {}, {"y"}]> : tensor<16x8x8xf32>
  return %0 : tensor<16x8x8xf32>
}

// CHECK-LABEL: func @reorder_sub_axes
func.func @reorder_sub_axes(%arg0: tensor<16x8xf32> {sdy.sharding = #sdy.sharding<@mesh4d_w4, [{"y", "w":(1)2, "z", "w":(2)2}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{}, {"x"}] %arg0 out_sharding=<@mesh4d_w4, [{"y", "w":(1)2, "z", "w":(2)2}, {"x"}]>
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %[[ALL_SLICE]] out_sharding=<@mesh4d_w4, [{"y", "z", "w"}, {"x"}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"w"} 0->1 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh4d_w4, [{"y", "z"}, {"x", "w"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"z"}, {}] %[[ALL_TO_ALL]] out_sharding=<@mesh4d_w4, [{"y"}, {"x", "w"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh4d_w4, [{"y"}, {"x", "w"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @replace_sub_axes
func.func @replace_sub_axes(%arg0: tensor<16x8xf32> {sdy.sharding = #sdy.sharding<@mesh4d_w4, [{"y", "z", "w":(2)2}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{}, {"x", "w":(1)2}] %arg0 out_sharding=<@mesh4d_w4, [{"y", "z", "w":(2)2}, {"x", "w":(1)2}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"w":(2)2} 0->1 %[[ALL_SLICE]] out_sharding=<@mesh4d_w4, [{"y", "z"}, {"x", "w"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"z"}, {}] %[[ALL_TO_ALL]] out_sharding=<@mesh4d_w4, [{"y"}, {"x", "w"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh4d_w4, [{"y"}, {"x", "w"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @replace_sub_axes_2
func.func @replace_sub_axes_2(%arg0: tensor<16x8xf32> {sdy.sharding = #sdy.sharding<@mesh4d_w4, [{"y", "z", "w":(1)2}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{}, {"x", "w":(2)2}] %arg0 out_sharding=<@mesh4d_w4, [{"y", "z", "w":(1)2}, {"x", "w":(2)2}]>
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %[[ALL_SLICE]] out_sharding=<@mesh4d_w4, [{"y", "z", "w":(2)2}, {"x", "w":(1)2}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"w":(2)2} 0->1 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh4d_w4, [{"y", "z"}, {"x", "w"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"z"}, {}] %[[ALL_TO_ALL]] out_sharding=<@mesh4d_w4, [{"y"}, {"x", "w"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh4d_w4, [{"y"}, {"x", "w"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @replace_sub_axes_3
func.func @replace_sub_axes_3(%arg0: tensor<16x8xf32> {sdy.sharding = #sdy.sharding<@mesh4d_w16, [{"y", "w":(4)2, "z", "w":(1)2}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{}, {"x", "w":(2)2, "w":(8)2}] %arg0 out_sharding=<@mesh4d_w16, [{"y", "w":(4)2, "z", "w":(1)2}, {"x", "w":(2)2, "w":(8)2}]>
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %[[ALL_SLICE]] out_sharding=<@mesh4d_w16, [{"y", "z", "w":(1)2, "w":(8)2}, {"x", "w":(2)4}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"w":(8)2} 0->1 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh4d_w16, [{"y", "z", "w":(1)2}, {"x", "w":(2)8}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"z", "w":(1)2}, {}] %[[ALL_TO_ALL]] out_sharding=<@mesh4d_w16, [{"y"}, {"x", "w":(2)8}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh4d_w16, [{"y"}, {"x", "w":(2)8}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// CHECK-LABEL: func @replace_sub_axes_4
func.func @replace_sub_axes_4(%arg0: tensor<16x8xf32> {sdy.sharding = #sdy.sharding<@mesh4d_w16, [{"y", "w":(4)2, "z", "w":(1)2}, {}]>}) -> tensor<16x8xf32> {
  // CHECK-NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{}, {"x", "w":(2)2, "w":(8)2}] %arg0 out_sharding=<@mesh4d_w16, [{"y", "w":(4)2, "z", "w":(1)2}, {"x", "w":(2)2, "w":(8)2}]>
  // CHECK-NEXT: %[[COLLECTIVE_PERMUTE:.*]] = sdy.collective_permute %[[ALL_SLICE]] out_sharding=<@mesh4d_w16, [{"y", "z", "w":(4)4}, {"x", "w":(1)4}]>
  // CHECK-NEXT: %[[ALL_TO_ALL:.*]] = sdy.all_to_all {"w":(4)4} 0->1 %[[COLLECTIVE_PERMUTE]] out_sharding=<@mesh4d_w16, [{"y", "z"}, {"x", "w"}]>
  // CHECK-NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"z"}, {}] %[[ALL_TO_ALL]] out_sharding=<@mesh4d_w16, [{"y"}, {"x", "w"}]>
  // CHECK-NEXT: return %[[ALL_GATHER]]
  %0 = sdy.reshard %arg0 <@mesh4d_w16, [{"y"}, {"x", "w"}]> : tensor<16x8xf32>
  return %0 : tensor<16x8xf32>
}

// TODO(b/391138813): Add proper support for axes that can't co-exist

// LABEL: func @reshard_with_non_divisible_subaxes_same_pre_size
// func.func @reshard_with_non_divisible_subaxes_same_pre_size(%arg0 : tensor<6x2xf32> {sdy.sharding=#sdy.sharding<@mesh1d_6, [{"x":(1)2}, {}]>}) -> tensor<6x2xf32> {
//   NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"x":(1)2}, {}] %arg0 out_sharding=<@mesh1d_6, [{}, {}]>
//   NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{"x":(1)3}, {}] %[[ALL_GATHER]] out_sharding=<@mesh1d_6, [{"x":(1)3}, {}]>
//   NEXT: return %[[ALL_SLICE]]
//  %0 = sdy.reshard %arg0 <@mesh1d_6, [{"x":(1)3}, {}]> :  tensor<6x2xf32>
//  return %0 : tensor<6x2xf32>
// }

// LABEL: func @reshard_with_non_divisible_overlapping_subaxes
// func.func @reshard_with_non_divisible_overlapping_subaxes(%arg0 : tensor<6x2xf32> {sdy.sharding=#sdy.sharding<@mesh1d_6, [{"x":(2)3}, {}]>}) -> tensor<6x2xf32> {
//   NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"x":(2)3}, {}] %arg0 out_sharding=<@mesh1d_6, [{}, {}]>
//   NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{"x":(1)3}, {}] %[[ALL_GATHER]] out_sharding=<@mesh1d_6, [{"x":(1)3}, {}]>
//   NEXT: return %[[ALL_SLICE]]
//  %0 = sdy.reshard %arg0 <@mesh1d_6, [{"x":(1)3}, {}]> :  tensor<6x2xf32>
//  return %0 : tensor<6x2xf32>
// }

// LABEL: func @reshard_with_non_divisible_overlapping_diff_dim
// func.func @reshard_with_non_divisible_overlapping_diff_dim(%arg0 : tensor<6x2xf32> {sdy.sharding=#sdy.sharding<@mesh1d_6, [{"x":(2)3}, {}]>}) -> tensor<6x2xf32> {
//   NEXT: %[[ALL_GATHER:.*]] = sdy.all_gather [{"x":(2)3}, {}] %arg0 out_sharding=<@mesh1d_6, [{}, {}]>
//   NEXT: %[[ALL_SLICE:.*]] = sdy.all_slice [{}, {"x":(1)3}] %[[ALL_GATHER]] out_sharding=<@mesh1d_6, [{}, {"x":(1)3}]>
//   NEXT: return %[[ALL_SLICE]]
//  %0 = sdy.reshard %arg0 <@mesh1d_6, [{}, {"x":(1)3}]> :  tensor<6x2xf32>
//  return %0 : tensor<6x2xf32>
// }
