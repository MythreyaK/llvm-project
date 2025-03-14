// RUN: mlir-opt -allow-unregistered-dialect %s -pass-pipeline='builtin.module(func.func(cse))' -split-input-file | FileCheck %s

// CHECK-LABEL: @simple_constant
func.func @simple_constant() -> (i32, i32) {
  // CHECK-NEXT: %[[VAR_c1_i32:.*]] = arith.constant 1 : i32
  %0 = arith.constant 1 : i32

  // CHECK-NEXT: return %[[VAR_c1_i32]], %[[VAR_c1_i32]] : i32, i32
  %1 = arith.constant 1 : i32
  return %0, %1 : i32, i32
}

// -----

// CHECK: #[[$MAP:.*]] = affine_map<(d0) -> (d0 mod 2)>
#map0 = affine_map<(d0) -> (d0 mod 2)>

// CHECK-LABEL: @basic
func.func @basic() -> (index, index) {
  // CHECK: %[[VAR_c0:[0-9a-zA-Z_]+]] = arith.constant 0 : index
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 0 : index

  // CHECK-NEXT: %[[VAR_0:[0-9a-zA-Z_]+]] = affine.apply #[[$MAP]](%[[VAR_c0]])
  %0 = affine.apply #map0(%c0)
  %1 = affine.apply #map0(%c1)

  // CHECK-NEXT: return %[[VAR_0]], %[[VAR_0]] : index, index
  return %0, %1 : index, index
}

// -----

// CHECK-LABEL: @many
func.func @many(f32, f32) -> (f32) {
^bb0(%a : f32, %b : f32):
  // CHECK-NEXT: %[[VAR_0:[0-9a-zA-Z_]+]] = arith.addf %{{.*}}, %{{.*}} : f32
  %c = arith.addf %a, %b : f32
  %d = arith.addf %a, %b : f32
  %e = arith.addf %a, %b : f32
  %f = arith.addf %a, %b : f32

  // CHECK-NEXT: %[[VAR_1:[0-9a-zA-Z_]+]] = arith.addf %[[VAR_0]], %[[VAR_0]] : f32
  %g = arith.addf %c, %d : f32
  %h = arith.addf %e, %f : f32
  %i = arith.addf %c, %e : f32

  // CHECK-NEXT: %[[VAR_2:[0-9a-zA-Z_]+]] = arith.addf %[[VAR_1]], %[[VAR_1]] : f32
  %j = arith.addf %g, %h : f32
  %k = arith.addf %h, %i : f32

  // CHECK-NEXT: %[[VAR_3:[0-9a-zA-Z_]+]] = arith.addf %[[VAR_2]], %[[VAR_2]] : f32
  %l = arith.addf %j, %k : f32

  // CHECK-NEXT: return %[[VAR_3]] : f32
  return %l : f32
}

// -----

/// Check that operations are not eliminated if they have different operands.
// CHECK-LABEL: @different_ops
func.func @different_ops() -> (i32, i32) {
  // CHECK: %[[VAR_c0_i32:[0-9a-zA-Z_]+]] = arith.constant 0 : i32
  // CHECK: %[[VAR_c1_i32:[0-9a-zA-Z_]+]] = arith.constant 1 : i32
  %0 = arith.constant 0 : i32
  %1 = arith.constant 1 : i32

  // CHECK-NEXT: return %[[VAR_c0_i32]], %[[VAR_c1_i32]] : i32, i32
  return %0, %1 : i32, i32
}

// -----

/// Check that operations are not eliminated if they have different result
/// types.
// CHECK-LABEL: @different_results
func.func @different_results(%arg0: tensor<*xf32>) -> (tensor<?x?xf32>, tensor<4x?xf32>) {
  // CHECK: %[[VAR_0:[0-9a-zA-Z_]+]] = tensor.cast %{{.*}} : tensor<*xf32> to tensor<?x?xf32>
  // CHECK-NEXT: %[[VAR_1:[0-9a-zA-Z_]+]] = tensor.cast %{{.*}} : tensor<*xf32> to tensor<4x?xf32>
  %0 = tensor.cast %arg0 : tensor<*xf32> to tensor<?x?xf32>
  %1 = tensor.cast %arg0 : tensor<*xf32> to tensor<4x?xf32>

  // CHECK-NEXT: return %[[VAR_0]], %[[VAR_1]] : tensor<?x?xf32>, tensor<4x?xf32>
  return %0, %1 : tensor<?x?xf32>, tensor<4x?xf32>
}

// -----

/// Check that operations are not eliminated if they have different attributes.
// CHECK-LABEL: @different_attributes
func.func @different_attributes(index, index) -> (i1, i1, i1) {
^bb0(%a : index, %b : index):
  // CHECK: %[[VAR_0:[0-9a-zA-Z_]+]] = arith.cmpi slt, %{{.*}}, %{{.*}} : index
  %0 = arith.cmpi slt, %a, %b : index

  // CHECK-NEXT: %[[VAR_1:[0-9a-zA-Z_]+]] = arith.cmpi ne, %{{.*}}, %{{.*}} : index
  /// Predicate 1 means inequality comparison.
  %1 = arith.cmpi ne, %a, %b : index
  %2 = "arith.cmpi"(%a, %b) {predicate = 1} : (index, index) -> i1

  // CHECK-NEXT: return %[[VAR_0]], %[[VAR_1]], %[[VAR_1]] : i1, i1, i1
  return %0, %1, %2 : i1, i1, i1
}

// -----

/// Check that operations with side effects are not eliminated.
// CHECK-LABEL: @side_effect
func.func @side_effect() -> (memref<2x1xf32>, memref<2x1xf32>) {
  // CHECK: %[[VAR_0:[0-9a-zA-Z_]+]] = memref.alloc() : memref<2x1xf32>
  %0 = memref.alloc() : memref<2x1xf32>

  // CHECK-NEXT: %[[VAR_1:[0-9a-zA-Z_]+]] = memref.alloc() : memref<2x1xf32>
  %1 = memref.alloc() : memref<2x1xf32>

  // CHECK-NEXT: return %[[VAR_0]], %[[VAR_1]] : memref<2x1xf32>, memref<2x1xf32>
  return %0, %1 : memref<2x1xf32>, memref<2x1xf32>
}

// -----

/// Check that operation definitions are properly propagated down the dominance
/// tree.
// CHECK-LABEL: @down_propagate_for
func.func @down_propagate_for() {
  // CHECK: %[[VAR_c1_i32:[0-9a-zA-Z_]+]] = arith.constant 1 : i32
  %0 = arith.constant 1 : i32

  // CHECK-NEXT: affine.for {{.*}} = 0 to 4 {
  affine.for %i = 0 to 4 {
    // CHECK-NEXT: "foo"(%[[VAR_c1_i32]], %[[VAR_c1_i32]]) : (i32, i32) -> ()
    %1 = arith.constant 1 : i32
    "foo"(%0, %1) : (i32, i32) -> ()
  }
  return
}

// -----

// CHECK-LABEL: @down_propagate
func.func @down_propagate() -> i32 {
  // CHECK-NEXT: %[[VAR_c1_i32:[0-9a-zA-Z_]+]] = arith.constant 1 : i32
  %0 = arith.constant 1 : i32

  // CHECK-NEXT: %[[VAR_true:[0-9a-zA-Z_]+]] = arith.constant true
  %cond = arith.constant true

  // CHECK-NEXT: cf.cond_br %[[VAR_true]], ^bb1, ^bb2(%[[VAR_c1_i32]] : i32)
  cf.cond_br %cond, ^bb1, ^bb2(%0 : i32)

^bb1: // CHECK: ^bb1:
  // CHECK-NEXT: cf.br ^bb2(%[[VAR_c1_i32]] : i32)
  %1 = arith.constant 1 : i32
  cf.br ^bb2(%1 : i32)

^bb2(%arg : i32):
  return %arg : i32
}

// -----

/// Check that operation definitions are NOT propagated up the dominance tree.
// CHECK-LABEL: @up_propagate_for
func.func @up_propagate_for() -> i32 {
  // CHECK: affine.for {{.*}} = 0 to 4 {
  affine.for %i = 0 to 4 {
    // CHECK-NEXT: %[[VAR_c1_i32_0:[0-9a-zA-Z_]+]] = arith.constant 1 : i32
    // CHECK-NEXT: "foo"(%[[VAR_c1_i32_0]]) : (i32) -> ()
    %0 = arith.constant 1 : i32
    "foo"(%0) : (i32) -> ()
  }

  // CHECK: %[[VAR_c1_i32:[0-9a-zA-Z_]+]] = arith.constant 1 : i32
  // CHECK-NEXT: return %[[VAR_c1_i32]] : i32
  %1 = arith.constant 1 : i32
  return %1 : i32
}

// -----

// CHECK-LABEL: func @up_propagate
func.func @up_propagate() -> i32 {
  // CHECK-NEXT:  %[[VAR_c0_i32:[0-9a-zA-Z_]+]] = arith.constant 0 : i32
  %0 = arith.constant 0 : i32

  // CHECK-NEXT: %[[VAR_true:[0-9a-zA-Z_]+]] = arith.constant true
  %cond = arith.constant true

  // CHECK-NEXT: cf.cond_br %[[VAR_true]], ^bb1, ^bb2(%[[VAR_c0_i32]] : i32)
  cf.cond_br %cond, ^bb1, ^bb2(%0 : i32)

^bb1: // CHECK: ^bb1:
  // CHECK-NEXT: %[[VAR_c1_i32:[0-9a-zA-Z_]+]] = arith.constant 1 : i32
  %1 = arith.constant 1 : i32

  // CHECK-NEXT: cf.br ^bb2(%[[VAR_c1_i32]] : i32)
  cf.br ^bb2(%1 : i32)

^bb2(%arg : i32): // CHECK: ^bb2
  // CHECK-NEXT: %[[VAR_c1_i32_0:[0-9a-zA-Z_]+]] = arith.constant 1 : i32
  %2 = arith.constant 1 : i32

  // CHECK-NEXT: %[[VAR_1:[0-9a-zA-Z_]+]] = arith.addi %{{.*}}, %[[VAR_c1_i32_0]] : i32
  %add = arith.addi %arg, %2 : i32

  // CHECK-NEXT: return %[[VAR_1]] : i32
  return %add : i32
}

// -----

/// The same test as above except that we are testing on a cfg embedded within
/// an operation region.
// CHECK-LABEL: func @up_propagate_region
func.func @up_propagate_region() -> i32 {
  // CHECK-NEXT: {{.*}} "foo.region"
  %0 = "foo.region"() ({
    // CHECK-NEXT:  %[[VAR_c0_i32:[0-9a-zA-Z_]+]] = arith.constant 0 : i32
    // CHECK-NEXT: %[[VAR_true:[0-9a-zA-Z_]+]] = arith.constant true
    // CHECK-NEXT: cf.cond_br

    %1 = arith.constant 0 : i32
    %true = arith.constant true
    cf.cond_br %true, ^bb1, ^bb2(%1 : i32)

  ^bb1: // CHECK: ^bb1:
    // CHECK-NEXT: %[[VAR_c1_i32:[0-9a-zA-Z_]+]] = arith.constant 1 : i32
    // CHECK-NEXT: cf.br

    %c1_i32 = arith.constant 1 : i32
    cf.br ^bb2(%c1_i32 : i32)

  ^bb2(%arg : i32): // CHECK: ^bb2(%[[VAR_1:.*]]: i32):
    // CHECK-NEXT: %[[VAR_c1_i32_0:[0-9a-zA-Z_]+]] = arith.constant 1 : i32
    // CHECK-NEXT: %[[VAR_2:[0-9a-zA-Z_]+]] = arith.addi %[[VAR_1]], %[[VAR_c1_i32_0]] : i32
    // CHECK-NEXT: "foo.yield"(%[[VAR_2]]) : (i32) -> ()

    %c1_i32_0 = arith.constant 1 : i32
    %2 = arith.addi %arg, %c1_i32_0 : i32
    "foo.yield" (%2) : (i32) -> ()
  }) : () -> (i32)
  return %0 : i32
}

// -----

/// This test checks that nested regions that are isolated from above are
/// properly handled.
// CHECK-LABEL: @nested_isolated
func.func @nested_isolated() -> i32 {
  // CHECK-NEXT: arith.constant 1
  %0 = arith.constant 1 : i32

  // CHECK-NEXT: builtin.module
  // CHECK-NEXT: @nested_func
  builtin.module {
    func.func @nested_func() {
      // CHECK-NEXT: arith.constant 1
      %foo = arith.constant 1 : i32
      "foo.yield"(%foo) : (i32) -> ()
    }
  }

  // CHECK: "foo.region"
  "foo.region"() ({
    // CHECK-NEXT: arith.constant 1
    %foo = arith.constant 1 : i32
    "foo.yield"(%foo) : (i32) -> ()
  }) : () -> ()

  return %0 : i32
}

// -----

/// This test is checking that CSE gracefully handles values in graph regions
/// where the use occurs before the def, and one of the defs could be CSE'd with
/// the other.
// CHECK-LABEL: @use_before_def
func.func @use_before_def() {
  // CHECK-NEXT: test.graph_region
  test.graph_region {
    // CHECK-NEXT: arith.addi
    %0 = arith.addi %1, %2 : i32

    // CHECK-NEXT: arith.constant 1
    // CHECK-NEXT: arith.constant 1
    %1 = arith.constant 1 : i32
    %2 = arith.constant 1 : i32

    // CHECK-NEXT: "foo.yield"(%{{.*}}) : (i32) -> ()
    "foo.yield"(%0) : (i32) -> ()
  }
  return
}

// -----

/// This test is checking that CSE is removing duplicated read op that follow
/// other.
// CHECK-LABEL: @remove_direct_duplicated_read_op
func.func @remove_direct_duplicated_read_op() -> i32 {
  // CHECK-NEXT: %[[READ_VALUE:.*]] = "test.op_with_memread"() : () -> i32
  %0 = "test.op_with_memread"() : () -> (i32)
  %1 = "test.op_with_memread"() : () -> (i32)
  // CHECK-NEXT: %{{.*}} = arith.addi %[[READ_VALUE]], %[[READ_VALUE]] : i32
  %2 = arith.addi %0, %1 : i32
  return %2 : i32
}

// -----

/// This test is checking that CSE is removing duplicated read op that follow
/// other.
// CHECK-LABEL: @remove_multiple_duplicated_read_op
func.func @remove_multiple_duplicated_read_op() -> i64 {
  // CHECK: %[[READ_VALUE:.*]] = "test.op_with_memread"() : () -> i64
  %0 = "test.op_with_memread"() : () -> (i64)
  %1 = "test.op_with_memread"() : () -> (i64)
  // CHECK-NEXT: %{{.*}} = arith.addi %{{.*}}, %[[READ_VALUE]] : i64
  %2 = arith.addi %0, %1 : i64
  %3 = "test.op_with_memread"() : () -> (i64)
  // CHECK-NEXT: %{{.*}} = arith.addi %{{.*}}, %{{.*}} : i64
  %4 = arith.addi %2, %3 : i64
  %5 = "test.op_with_memread"() : () -> (i64)
  // CHECK-NEXT: %{{.*}} = arith.addi %{{.*}}, %{{.*}} : i64
  %6 = arith.addi %4, %5 : i64
  // CHECK-NEXT: return %{{.*}} : i64
  return %6 : i64
}

// -----

/// This test is checking that CSE is not removing duplicated read op that
/// have write op in between.
// CHECK-LABEL: @dont_remove_duplicated_read_op_with_sideeffecting
func.func @dont_remove_duplicated_read_op_with_sideeffecting() -> i32 {
  // CHECK-NEXT: %[[READ_VALUE0:.*]] = "test.op_with_memread"() : () -> i32
  %0 = "test.op_with_memread"() : () -> (i32)
  "test.op_with_memwrite"() : () -> ()
  // CHECK: %[[READ_VALUE1:.*]] = "test.op_with_memread"() : () -> i32
  %1 = "test.op_with_memread"() : () -> (i32)
  // CHECK-NEXT: %{{.*}} = arith.addi %[[READ_VALUE0]], %[[READ_VALUE1]] : i32
  %2 = arith.addi %0, %1 : i32
  return %2 : i32
}

// -----

// Check that an operation with a single region can CSE.
func.func @cse_single_block_ops(%a : tensor<?x?xf32>, %b : tensor<?x?xf32>)
  -> (tensor<?x?xf32>, tensor<?x?xf32>) {
  %0 = test.cse_of_single_block_op inputs(%a, %b) {
    ^bb0(%arg0 : f32):
    test.region_yield %arg0 : f32
  } : tensor<?x?xf32>, tensor<?x?xf32> -> tensor<?x?xf32>
  %1 = test.cse_of_single_block_op inputs(%a, %b) {
    ^bb0(%arg0 : f32):
    test.region_yield %arg0 : f32
  } : tensor<?x?xf32>, tensor<?x?xf32> -> tensor<?x?xf32>
  return %0, %1 : tensor<?x?xf32>, tensor<?x?xf32>
}
// CHECK-LABEL: func @cse_single_block_ops
//       CHECK:   %[[OP:.+]] = test.cse_of_single_block_op
//   CHECK-NOT:   test.cse_of_single_block_op
//       CHECK:   return %[[OP]], %[[OP]]

// -----

// Operations with different number of bbArgs dont CSE.
func.func @no_cse_varied_bbargs(%a : tensor<?x?xf32>, %b : tensor<?x?xf32>)
  -> (tensor<?x?xf32>, tensor<?x?xf32>) {
  %0 = test.cse_of_single_block_op inputs(%a, %b) {
    ^bb0(%arg0 : f32, %arg1 : f32):
    test.region_yield %arg0 : f32
  } : tensor<?x?xf32>, tensor<?x?xf32> -> tensor<?x?xf32>
  %1 = test.cse_of_single_block_op inputs(%a, %b) {
    ^bb0(%arg0 : f32):
    test.region_yield %arg0 : f32
  } : tensor<?x?xf32>, tensor<?x?xf32> -> tensor<?x?xf32>
  return %0, %1 : tensor<?x?xf32>, tensor<?x?xf32>
}
// CHECK-LABEL: func @no_cse_varied_bbargs
//       CHECK:   %[[OP0:.+]] = test.cse_of_single_block_op
//       CHECK:   %[[OP1:.+]] = test.cse_of_single_block_op
//       CHECK:   return %[[OP0]], %[[OP1]]

// -----

// Operations with different regions dont CSE
func.func @no_cse_region_difference_simple(%a : tensor<?x?xf32>, %b : tensor<?x?xf32>)
  -> (tensor<?x?xf32>, tensor<?x?xf32>) {
  %0 = test.cse_of_single_block_op inputs(%a, %b) {
    ^bb0(%arg0 : f32, %arg1 : f32):
    test.region_yield %arg0 : f32
  } : tensor<?x?xf32>, tensor<?x?xf32> -> tensor<?x?xf32>
  %1 = test.cse_of_single_block_op inputs(%a, %b) {
    ^bb0(%arg0 : f32, %arg1 : f32):
    test.region_yield %arg1 : f32
  } : tensor<?x?xf32>, tensor<?x?xf32> -> tensor<?x?xf32>
  return %0, %1 : tensor<?x?xf32>, tensor<?x?xf32>
}
// CHECK-LABEL: func @no_cse_region_difference_simple
//       CHECK:   %[[OP0:.+]] = test.cse_of_single_block_op
//       CHECK:   %[[OP1:.+]] = test.cse_of_single_block_op
//       CHECK:   return %[[OP0]], %[[OP1]]

// -----

// Operation with identical region with multiple statements CSE.
func.func @cse_single_block_ops_identical_bodies(%a : tensor<?x?xf32>, %b : tensor<?x?xf32>, %c : f32, %d : i1)
  -> (tensor<?x?xf32>, tensor<?x?xf32>) {
  %0 = test.cse_of_single_block_op inputs(%a, %b) {
    ^bb0(%arg0 : f32, %arg1 : f32):
    %1 = arith.divf %arg0, %arg1 : f32
    %2 = arith.remf %arg0, %c : f32
    %3 = arith.select %d, %1, %2 : f32
    test.region_yield %3 : f32
  } : tensor<?x?xf32>, tensor<?x?xf32> -> tensor<?x?xf32>
  %1 = test.cse_of_single_block_op inputs(%a, %b) {
    ^bb0(%arg0 : f32, %arg1 : f32):
    %1 = arith.divf %arg0, %arg1 : f32
    %2 = arith.remf %arg0, %c : f32
    %3 = arith.select %d, %1, %2 : f32
    test.region_yield %3 : f32
  } : tensor<?x?xf32>, tensor<?x?xf32> -> tensor<?x?xf32>
  return %0, %1 : tensor<?x?xf32>, tensor<?x?xf32>
}
// CHECK-LABEL: func @cse_single_block_ops_identical_bodies
//       CHECK:   %[[OP:.+]] = test.cse_of_single_block_op
//   CHECK-NOT:   test.cse_of_single_block_op
//       CHECK:   return %[[OP]], %[[OP]]

// -----

// Operation with non-identical regions dont CSE.
func.func @no_cse_single_block_ops_different_bodies(%a : tensor<?x?xf32>, %b : tensor<?x?xf32>, %c : f32, %d : i1)
  -> (tensor<?x?xf32>, tensor<?x?xf32>) {
  %0 = test.cse_of_single_block_op inputs(%a, %b) {
    ^bb0(%arg0 : f32, %arg1 : f32):
    %1 = arith.divf %arg0, %arg1 : f32
    %2 = arith.remf %arg0, %c : f32
    %3 = arith.select %d, %1, %2 : f32
    test.region_yield %3 : f32
  } : tensor<?x?xf32>, tensor<?x?xf32> -> tensor<?x?xf32>
  %1 = test.cse_of_single_block_op inputs(%a, %b) {
    ^bb0(%arg0 : f32, %arg1 : f32):
    %1 = arith.divf %arg0, %arg1 : f32
    %2 = arith.remf %arg0, %c : f32
    %3 = arith.select %d, %2, %1 : f32
    test.region_yield %3 : f32
  } : tensor<?x?xf32>, tensor<?x?xf32> -> tensor<?x?xf32>
  return %0, %1 : tensor<?x?xf32>, tensor<?x?xf32>
}
// CHECK-LABEL: func @no_cse_single_block_ops_different_bodies
//       CHECK:   %[[OP0:.+]] = test.cse_of_single_block_op
//       CHECK:   %[[OP1:.+]] = test.cse_of_single_block_op
//       CHECK:   return %[[OP0]], %[[OP1]]

// -----

func.func @failing_issue_59135(%arg0: tensor<2x2xi1>, %arg1: f32, %arg2 : tensor<2xi1>) -> (tensor<2xi1>, tensor<2xi1>) {
  %false_2 = arith.constant false
  %true_5 = arith.constant true
  %9 = test.cse_of_single_block_op inputs(%arg2) {
  ^bb0(%out: i1):
    %true_144 = arith.constant true
    test.region_yield %true_144 : i1
  } : tensor<2xi1> -> tensor<2xi1>
  %15 = test.cse_of_single_block_op inputs(%arg2) {
  ^bb0(%out: i1):
    %true_144 = arith.constant true
    test.region_yield %true_144 : i1
  } : tensor<2xi1> -> tensor<2xi1>
  %93 = arith.maxsi %false_2, %true_5 : i1
  return %9, %15 : tensor<2xi1>, tensor<2xi1>
}
// CHECK-LABEL: func @failing_issue_59135
//       CHECK:   %[[TRUE:.+]] = arith.constant true
//       CHECK:   %[[OP:.+]] = test.cse_of_single_block_op
//       CHECK:     test.region_yield %[[TRUE]]
//       CHECK:   return %[[OP]], %[[OP]]

// -----

func.func @cse_multiple_regions(%c: i1, %t: tensor<5xf32>) -> (tensor<5xf32>, tensor<5xf32>) {
  %r1 = scf.if %c -> (tensor<5xf32>) {
    %0 = tensor.empty() : tensor<5xf32>
    scf.yield %0 : tensor<5xf32>
  } else {
    scf.yield %t : tensor<5xf32>
  }
  %r2 = scf.if %c -> (tensor<5xf32>) {
    %0 = tensor.empty() : tensor<5xf32>
    scf.yield %0 : tensor<5xf32>
  } else {
    scf.yield %t : tensor<5xf32>
  }
  return %r1, %r2 : tensor<5xf32>, tensor<5xf32>
}
// CHECK-LABEL: func @cse_multiple_regions
//       CHECK:   %[[if:.*]] = scf.if {{.*}} {
//       CHECK:     tensor.empty
//       CHECK:     scf.yield
//       CHECK:   } else {
//       CHECK:     scf.yield
//       CHECK:   }
//   CHECK-NOT:   scf.if
//       CHECK:   return %[[if]], %[[if]]

// -----

// CHECK-LABEL: @cse_recursive_effects_success
func.func @cse_recursive_effects_success() -> (i32, i32, i32) {
  // CHECK-NEXT: %[[READ_VALUE:.*]] = "test.op_with_memread"() : () -> i32
  %0 = "test.op_with_memread"() : () -> (i32)

  // do something with recursive effects, containing no side effects
  %true = arith.constant true
  // CHECK-NEXT: %[[TRUE:.+]] = arith.constant true
  // CHECK-NEXT: %[[IF:.+]] = scf.if %[[TRUE]] -> (i32) {
  %1 = scf.if %true -> (i32) {
    %c42 = arith.constant 42 : i32
    scf.yield %c42 : i32
    // CHECK-NEXT: %[[C42:.+]] = arith.constant 42 : i32
    // CHECK-NEXT: scf.yield %[[C42]]
    // CHECK-NEXT: } else {
  } else {
    %c24 = arith.constant 24 : i32
    scf.yield %c24 : i32
    // CHECK-NEXT: %[[C24:.+]] = arith.constant 24 : i32
    // CHECK-NEXT: scf.yield %[[C24]]
    // CHECK-NEXT: }
  }

  // %2 can be removed
  // CHECK-NEXT: return %[[READ_VALUE]], %[[READ_VALUE]], %[[IF]] : i32, i32, i32
  %2 = "test.op_with_memread"() : () -> (i32)
  return %0, %2, %1 : i32, i32, i32
}

// -----

// CHECK-LABEL: @cse_recursive_effects_failure
func.func @cse_recursive_effects_failure() -> (i32, i32, i32) {
  // CHECK-NEXT: %[[READ_VALUE:.*]] = "test.op_with_memread"() : () -> i32
  %0 = "test.op_with_memread"() : () -> (i32)

  // do something with recursive effects, containing a write effect
  %true = arith.constant true
  // CHECK-NEXT: %[[TRUE:.+]] = arith.constant true
  // CHECK-NEXT: %[[IF:.+]] = scf.if %[[TRUE]] -> (i32) {
  %1 = scf.if %true -> (i32) {
    "test.op_with_memwrite"() : () -> ()
    // CHECK-NEXT: "test.op_with_memwrite"() : () -> ()
    %c42 = arith.constant 42 : i32
    scf.yield %c42 : i32
    // CHECK-NEXT: %[[C42:.+]] = arith.constant 42 : i32
    // CHECK-NEXT: scf.yield %[[C42]]
    // CHECK-NEXT: } else {
  } else {
    %c24 = arith.constant 24 : i32
    scf.yield %c24 : i32
    // CHECK-NEXT: %[[C24:.+]] = arith.constant 24 : i32
    // CHECK-NEXT: scf.yield %[[C24]]
    // CHECK-NEXT: }
  }

  // %2 can not be be removed because of the write
  // CHECK-NEXT: %[[READ_VALUE2:.*]] = "test.op_with_memread"() : () -> i32
  // CHECK-NEXT: return %[[READ_VALUE]], %[[READ_VALUE2]], %[[IF]] : i32, i32, i32
  %2 = "test.op_with_memread"() : () -> (i32)
  return %0, %2, %1 : i32, i32, i32
}
