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

#ifndef SHARDY_ROUND_TRIP_IMPORT_UTILS_H_
#define SHARDY_ROUND_TRIP_IMPORT_UTILS_H_

#include <cstdint>
#include <optional>
#include <string>

#include "mlir/AsmParser/AsmParser.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/IR/Attributes.h"
#include "mlir/IR/Builders.h"
#include "mlir/IR/BuiltinAttributes.h"
#include "mlir/IR/MLIRContext.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/IR/TypeRange.h"
#include "mlir/Support/LLVM.h"
#include "stablehlo/dialect/StablehloOps.h"

namespace mlir {
namespace sdy {

// Gets the "frontend_attributes" `DictionaryAttr` from `op`. If it doesn't
// exist, return nullptr.
DictionaryAttr getFrontendAttrs(Operation* op);

// Gets the `frontend_attributes` `DictionaryAttr` from `funcOp`'s arg at
// `index`. If it doesn't exist, return nullptr.
DictionaryAttr getFuncArgFrontendAttrs(func::FuncOp funcOp, unsigned int index);

// Remove `attributeName` from the frontend attributes of `op`.
void removeFrontendAttribute(Operation* op, StringRef attributeName);

// Remove `attributeName` from the argument at `argNum`'s frontend attributes
// of `funcOp`.
void removeFrontendAttribute(func::FuncOp funcOp, StringRef attributeName,
                             int64_t argNum);

// Checks if "frontend_attributes" `DictionaryAttr` from `op` contains `key`.
bool hasFrontendAttr(Operation* op, StringRef key);

// Checks if `dictAttr` exists and contains `key`.
bool hasKey(DictionaryAttr dictAttr, StringRef key);

std::string cunescape(llvm::StringRef escapedValue);

// Parses `attrName` from `dictAttr` to an attribute of type `AttrTy`.
template <typename AttrTy>
AttrTy parseStringAttr(DictionaryAttr dictAttr, llvm::StringRef attrName) {
  if (Attribute stringAttr = dictAttr.get(attrName)) {
    std::string unescapedValue =
        cunescape(cast<StringAttr>(stringAttr).getValue());
    return cast<AttrTy>(
        parseAttribute(unescapedValue, stringAttr.getContext()));
  }
  return nullptr;
}

// Checks if `op`'s "frontend_attributes" `DictionaryAttr` contains `attrName`
// and parses it to an attribute of type `AttrTy`. If it doesn't exist, then
// returns std::nullopt.
template <typename AttrTy>
std::optional<AttrTy> tryGetFrontendAttr(Operation* op, StringRef attrName) {
  DictionaryAttr dictAttr = getFrontendAttrs(op);
  if (hasKey(dictAttr, attrName)) {
    return parseStringAttr<AttrTy>(dictAttr, attrName);
  }
  return std::nullopt;
}

// Whether `op` is a Python callback custom call.
bool isPythonCallbackCustomCall(stablehlo::CustomCallOp op);

}  // namespace sdy
}  // namespace mlir

#endif  // SHARDY_ROUND_TRIP_IMPORT_UTILS_H_
