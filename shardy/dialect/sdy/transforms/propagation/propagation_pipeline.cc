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

#include "mlir/Pass/PassManager.h"
#include "mlir/Pass/PassRegistry.h"
#include "mlir/Support/LLVM.h"
#include "shardy/dialect/sdy/transforms/export/passes.h"
#include "shardy/dialect/sdy/transforms/import/passes.h"
#include "shardy/dialect/sdy/transforms/propagation/passes.h"
#include "shardy/dialect/sdy/transforms/propagation/user_priority_propagation.h"

namespace mlir {
namespace sdy {

namespace {

void populateExportOptions(ExportOptions& options,
                           const PropagationOptions& propOptions) {
  options.keepShardingRules = propOptions.keepShardingRules;
  options.dumpDirectory = propOptions.dumpDirectory.str();
  options.skipConvertToReshard = propOptions.skipConvertToReshard;
  options.enableInsertExplicitCollectives =
      propOptions.enableInsertExplicitCollectives;
}

}  // namespace

void addPropagationPipeline(OpPassManager& pm,
                            const PropagationOptions& options) {
  addImportPipeline(pm, options.dumpDirectory, options.skipInline);
  {
    PropagationOptions optionsWithKeepShardingRules = options;
    optionsWithKeepShardingRules.keepShardingRules = true;
    pm.addPass(createUserPriorityPropagationPass(optionsWithKeepShardingRules));
  }
  ExportOptions exportOptions;
  populateExportOptions(exportOptions, options);
  addExportPipeline(pm, exportOptions);
}

void registerPropagationPipeline() {
  PassPipelineRegistration<>(
      "sdy-propagation-pipeline",
      "Runs the SDY propagation pass, preceded by a sequence of import passes "
      "needed as a pre-processing step for propagation",
      [](OpPassManager& pm) {
        return addPropagationPipeline(pm);
      });
}

}  // namespace sdy
}  // namespace mlir
