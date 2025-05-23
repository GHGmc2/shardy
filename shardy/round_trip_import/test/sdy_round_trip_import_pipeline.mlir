// RUN: sdy_opt %s --split-input-file -sdy-round-trip-import-pipeline 2>&1 | FileCheck %s

// CHECK-LABEL: module @multiple_func_result_shardings
module @multiple_func_result_shardings attributes {mhlo.frontend_attributes = {xla.sdy.meshes =
    "{mesh = #sdy.mesh<[\\\22a\\\22=8, \\\22b\\\22=8, \\\22c\\\22=8]>, mesh2 = #sdy.mesh<[\\\22a\\\22=1, \\\22b\\\22=4, \\\22c\\\22=1]>}"}} {
  // CHECK: sdy.mesh @mesh = <["a"=8, "b"=8, "c"=8]>

  // CHECK: sdy.mesh @mesh2 = <["a"=1, "b"=4, "c"=1]>

  // CHECK-LABEL: func @func_results_with_sharding
  // CHECK-SAME:    %arg0: tensor<32xi32> {sdy.sharding = #sdy.sharding<@mesh, [{"b"}p2]>},
  // CHECK-SAME:    %arg1: tensor<32xi32> {sdy.sharding = #sdy.sharding<@mesh, [{"a"}p1]>},
  // CHECK-SAME:    %arg2: tensor<32xi32> {sdy.sharding = #sdy.sharding<@mesh, [{"c"}p0]>}
  // CHECK-SAME:  ) -> (
  // CHECK-SAME:    tensor<32xi32> {sdy.sharding = #sdy.sharding<@mesh, [{"a"}p0]>},
  // CHECK-SAME:    tensor<32xi32> {sdy.sharding = #sdy.sharding<@mesh, [{"b"}p2]>},
  // CHECK-SAME:    tensor<32xi32> {sdy.sharding = #sdy.sharding<@mesh, [{"a"}p1]>},
  // CHECK-SAME:    tensor<32xi32> {sdy.sharding = #sdy.sharding<@mesh, [{"c"}p0]>},
  // CHECK-SAME:    tensor<32xi32> {sdy.sharding = #sdy.sharding<@mesh, [{"b"}p2]>},
  // CHECK-SAME:    tensor<32xi32> {sdy.sharding = #sdy.sharding<@mesh, [{"a"}p3]>}) {
  // CHECK-NEXT:   return %arg0, %arg1, %arg0, %arg1, %arg1, %arg2
  // CHECK-NEXT: }
  func.func @func_results_with_sharding(
    %arg0: tensor<32xi32> {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding<@mesh, [{\\\22b\\\22}p2]>"}},
    %arg1: tensor<32xi32> {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding<@mesh, [{\\\22a\\\22}p1]>"}},
    %arg2: tensor<32xi32> {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding<@mesh, [{\\\22c\\\22}p0]>"}}
  ) -> (tensor<32xi32>, tensor<32xi32>, tensor<32xi32>, tensor<32xi32>, tensor<32xi32>, tensor<32xi32>) {
    %0 = stablehlo.custom_call @xla.sdy.FuncResultSharding(%arg0) {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<@mesh, [{\\\22a\\\22}p0]>]>"}} : (tensor<32xi32>) -> tensor<32xi32>
    %1 = stablehlo.custom_call @xla.sdy.FuncResultSharding(%arg1) {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<@mesh, [{\\\22b\\\22}p2]>]>"}} : (tensor<32xi32>) -> tensor<32xi32>
    %2 = stablehlo.custom_call @xla.sdy.FuncResultSharding(%arg0) {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<@mesh, [{\\\22a\\\22}p1]>]>"}} : (tensor<32xi32>) -> tensor<32xi32>
    %3 = stablehlo.custom_call @xla.sdy.FuncResultSharding(%arg1) {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<@mesh, [{\\\22c\\\22}p0]>]>"}} : (tensor<32xi32>) -> tensor<32xi32>
    %4 = stablehlo.custom_call @xla.sdy.FuncResultSharding(%arg2) {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<@mesh, [{\\\22a\\\22}p3]>]>"}} : (tensor<32xi32>) -> tensor<32xi32>
    return %0, %1, %2, %3, %1, %4 : tensor<32xi32>, tensor<32xi32>, tensor<32xi32>, tensor<32xi32>, tensor<32xi32>, tensor<32xi32>
  }

  // This might happen due to inlined funcs that originally had result shardings
  // CHECK-LABEL: func @func_result_shardings_used_by_other_ops(
  // CHECK-SAME:    %arg0: tensor<32xi32>, %arg1: tensor<32xi32>
  // CHECK-SAME:  ) -> (
  // CHECK-SAME:    tensor<32xi32> {sdy.sharding = #sdy.sharding<@mesh, [{"b"}p2]>},
  // CHECK-SAME:    tensor<32xi32>) {
  // CHECK-NEXT:   %[[ADD:.*]] =  stablehlo.add %arg0, %arg1
  // CHECK-NEXT:   return %arg0, %[[ADD]]
  // CHECK-NEXT: }
  func.func @func_result_shardings_used_by_other_ops(
    %arg0: tensor<32xi32>, %arg1: tensor<32xi32>
  ) -> (tensor<32xi32>, tensor<32xi32>) {
    %0 = stablehlo.custom_call @xla.sdy.FuncResultSharding(%arg0) {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<@mesh, [{\\\22a\\\22}p0]>]>"}} : (tensor<32xi32>) -> tensor<32xi32>
    %1 = stablehlo.custom_call @xla.sdy.FuncResultSharding(%0) {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<@mesh, [{\\\22b\\\22}p2]>]>"}} : (tensor<32xi32>) -> tensor<32xi32>
    %2 = stablehlo.custom_call @xla.sdy.FuncResultSharding(%arg1) {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<@mesh, [{\\\22a\\\22}p3]>]>"}} : (tensor<32xi32>) -> tensor<32xi32>
    %3 = stablehlo.add %1, %2 : tensor<32xi32>
    return %1, %3 : tensor<32xi32>, tensor<32xi32>
  }

  // CHECK-LABEL: func @while_with_sinked_constants
  func.func @while_with_sinked_constants(%arg0: tensor<32x96xf32>) -> tensor<32x96xf32> {
    // CHECK-NEXT: %[[C0:.*]] = stablehlo.constant dense<0>
    // CHECK-NEXT: %[[WHILE:.*]]:2 = stablehlo.while(%iterArg = %arg0, %iterArg_0 = %[[C0]])
    // CHECK-NEXT:   cond {
    // CHECK-NEXT:   %[[C32:.*]] = stablehlo.constant dense<32>
    // CHECK-NEXT:   %[[COND:.*]] = stablehlo.compare LT, %iterArg_0, %[[C32]]
    // CHECK-NEXT:   stablehlo.return %[[COND]]
    // CHECK-NEXT: } do {
    // CHECK-NEXT:   %[[C1:.*]] = stablehlo.constant dense<1>
    // CHECK-NEXT:   %[[ADD_0:.*]] = stablehlo.add %iterArg_0, %[[C1]]
    // CHECK-NEXT:   %[[ADD_1:.*]] = stablehlo.add %iterArg, %iterArg
    // CHECK-NEXT:   stablehlo.return %[[ADD_1]], %[[ADD_0]]
    // CHECK-NEXT: }
    // CHECK-NEXT: return %[[WHILE]]#0
    %0 = stablehlo.constant dense<0> : tensor<i32>
    %1:2 = stablehlo.while(%iterArg = %arg0, %iterArg_0 = %0) : tensor<32x96xf32>, tensor<i32>
      cond {
      %2 = stablehlo.constant dense<32> : tensor<i32>
      %3 = stablehlo.compare LT, %iterArg_0, %2 : (tensor<i32>, tensor<i32>) -> tensor<i1>
      stablehlo.return %3 : tensor<i1>
    } do {
      %2 = stablehlo.constant dense<1> : tensor<i32>
      %3 = stablehlo.add %iterArg_0, %2 : tensor<i32>
      %4 = stablehlo.add %iterArg, %iterArg : tensor<32x96xf32>
      stablehlo.return %4, %3 : tensor<32x96xf32>, tensor<i32>
    }
    return %1#0 : tensor<32x96xf32>
  }

  // CHECK-LABEL: func @discard_shardings_on_unknown_ops(
  // CHECK-SAME: %arg0: tensor<32xi32> {sdy.sharding = #sdy.sharding<@mesh, [{"a"}p0]>})
  // CHECK-SAME: -> (tensor<32xi32> {sdy.sharding = #sdy.sharding<@mesh, [{"a"}p4]>}) {
  func.func @discard_shardings_on_unknown_ops(
    %arg0: tensor<32xi32> {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding<@mesh, [{\\\22a\\\22}p0]>"}}
  ) -> tensor<32xi32> {
    // CHECK-NEXT: %[[ADD:.*]] = stablehlo.add %arg0, %arg0 : tensor<32xi32>
    // CHECK-NEXT: %[[SHARDING:.*]] = sdy.sharding_constraint %[[ADD]] <@mesh, [{"a"}p2]> : tensor<32xi32>
    // CHECK-NEXT: %[[UNKNOWN:.*]] = stablehlo.custom_call @UnknownCustomCall(%[[SHARDING]]) : (tensor<32xi32>) -> tensor<32xi32>
    // CHECK-NEXT: return %[[UNKNOWN]]
    %0 = stablehlo.add %arg0, %arg0 {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<@mesh, [{\\\22a\\\22}p1]>]>"}} : tensor<32xi32>
    %1 = stablehlo.custom_call @Sharding(%0) {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<@mesh, [{\\\22a\\\22}p2]>]>"}} : (tensor<32xi32>) -> tensor<32xi32>
    %2 = stablehlo.custom_call @UnknownCustomCall(%1) {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<@mesh, [{\\\22a\\\22}p3]>]>"}} : (tensor<32xi32>) -> tensor<32xi32>
    %3 = stablehlo.custom_call @xla.sdy.FuncResultSharding(%2) {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<@mesh, [{\\\22a\\\22}p4]>]>"}} : (tensor<32xi32>) -> tensor<32xi32>
    return %3 : tensor<32xi32>
  }

  // CHECK-LABEL: func @inlined_mesh(
  // CHECK-SAME: %arg0: tensor<32xi32> {sdy.sharding = #sdy.sharding<mesh<["a"=2, "b"=2]>, [{"a"}]>})
  // CHECK-SAME: -> (tensor<32xi32> {sdy.sharding = #sdy.sharding<mesh<[], device_ids=[5]>, []>}) {
  func.func @inlined_mesh(
    %arg0: tensor<32xi32> {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding<mesh<[\\\22a\\\22=2, \\\22b\\\22=2]>, [{\\\22a\\\22}]>"}}
  ) -> tensor<32xi32> {
    // CHECK-NEXT: %[[SHARDING:.*]] = sdy.sharding_constraint %arg0 <mesh<["c"=4]>, [{"c"}]> : tensor<32xi32>
    // CHECK-NEXT: return %[[SHARDING]]
    %0 = stablehlo.custom_call @Sharding(%arg0) {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<mesh<[\\\22c\\\22=4]>, [{\\\22c\\\22}]>]>"}} : (tensor<32xi32>) -> tensor<32xi32>
    %1 = stablehlo.custom_call @xla.sdy.FuncResultSharding(%0) {mhlo.frontend_attributes = {xla.sdy.sharding = "#sdy.sharding_per_value<[<mesh<[], device_ids=[5]>, []>]>"}} : (tensor<32xi32>) -> tensor<32xi32>
    return %1 : tensor<32xi32>
  }
}

// -----

// CHECK-NOT: sdy.mesh @mesh

module @no_meshes_module attributes {mhlo.frontend_attributes = {xla.sdy.meshes = "{}"}} {
  // CHECK-LABEL: func @no_sharding_rule
  func.func @no_sharding_rule(%arg0: tensor<8x2xf32>, %arg1: tensor<8x2xf32>) -> tensor<8x2xf64> {
    // CHECK-NEXT: stablehlo.custom_call @foo(%arg0, %arg1) : (tensor<8x2xf32>, tensor<8x2xf32>) -> tensor<8x2xf64>
    %0 = stablehlo.custom_call @foo(%arg0, %arg1) : (tensor<8x2xf32>, tensor<8x2xf32>) -> tensor<8x2xf64>
   return %0 : tensor<8x2xf64>
  }

  // CHECK-LABEL: func @op_sharding_rule
  func.func @op_sharding_rule(%arg0: tensor<8x2xf32>, %arg1: tensor<8x2xf32>) -> tensor<8x2xf64> {
    // CHECK-NEXT: stablehlo.custom_call @foo(%arg0, %arg1) {sdy.sharding_rule = #sdy.op_sharding_rule<([i, j], [i, j])->([i, j]) {i=8, j=2}>}
    %0 = stablehlo.custom_call @foo(%arg0, %arg1)
      {mhlo.frontend_attributes = {xla.sdy.sharding_rule = "#sdy.op_sharding_rule<([i, j], [i, j])->([i, j]) {i=8, j=2}>"}} : (tensor<8x2xf32>, tensor<8x2xf32>) -> tensor<8x2xf64>
    return %0 : tensor<8x2xf64>
  }
}

// -----

// CHECK-NOT: sdy.mesh @mesh

module @no_meshes_attr_module {
  // CHECK-LABEL: func @op_sharding_rule
  func.func @op_sharding_rule(%arg0: tensor<8x2xf32>, %arg1: tensor<8x2xf32>) -> tensor<8x2xf64> {
    // CHECK-NEXT: stablehlo.custom_call @foo(%arg0, %arg1) {sdy.sharding_rule = #sdy.op_sharding_rule<([i, j], [i, j])->([i, j]) {i=8, j=2}>}
    %0 = stablehlo.custom_call @foo(%arg0, %arg1)
      {mhlo.frontend_attributes = {xla.sdy.sharding_rule = "#sdy.op_sharding_rule<([i, j], [i, j])->([i, j]) {i=8, j=2}>"}} : (tensor<8x2xf32>, tensor<8x2xf32>) -> tensor<8x2xf64>
    return %0 : tensor<8x2xf64>
  }
}

// -----

// CHECK-LABEL: func @import_sharding_group
// CHECK-SAME:      %arg0: tensor<8x8xf32>) -> tensor<8x8xf32> {
func.func @import_sharding_group(%arg0: tensor<8x8xf32>) -> tensor<8x8xf32> {
  // CHECK sdy.sharding_group %arg0 group_id = 21:  tensor<8x8xf32>
  stablehlo.custom_call @xla.sdy.ShardingGroup(%arg0) {has_side_effect = true, mhlo.frontend_attributes = {xla.sdy.sharding_group_id = "21 : i64"}} : (tensor<8x8xf32>) -> ()
  return %arg0 : tensor<8x8xf32>
}

// -----

func.func @callback_no_result(%arg0: tensor<f64>) {
  // CHECK:      %[[C:.*]] = stablehlo.constant
  // CHECK-NEXT: stablehlo.custom_call @xla_python_cpu_callback(%[[C]], %arg0) {
  // CHECK-SAME:   api_version = 2 : i32, backend_config = "56238273106176",
  // CHECK-SAME:   has_side_effect = true,
  // CHECK-SAME:   operand_layouts = [dense<> : tensor<0xindex>, dense<> : tensor<0xindex>],
  // CHECK-SAME:   result_layouts = []
  // CHECK-SAME: } : (tensor<i64>, tensor<f64>) -> ()
  %c = stablehlo.constant dense<56238273106176> : tensor<i64>
  stablehlo.custom_call @xla_python_cpu_callback(%c, %arg0) {api_version = 2 : i32, backend_config = "56238273106176", has_side_effect = true, operand_layouts = [dense<> : tensor<0xindex>, dense<> : tensor<0xindex>], result_layouts = []} : (tensor<i64>, tensor<f64>) -> ()
  return
}
