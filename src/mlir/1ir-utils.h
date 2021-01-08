// Copyright Microsoft and Project Verona Contributors.
// SPDX-License-Identifier: MIT

#pragma once

#include "compiler/ir/ir.h"

#include <string>

using BaseStmt = verona::compiler::BaseStatement;
using SrcMgr = verona::compiler::SourceManager;

namespace mlir::verona
{
  /**
   * This is a bag of utility functions to handle 1IR lookups and fail-safe
   * operations. While the 1IR design is still in flux, we can keep this around,
   * but once we're set on its structure, this should be incorporated elsewhere.
   *
   * We hold no values here, so we don't need to worry about ownership. All
   * methods are static and work on 1IR nodes directly. The ownership of those
   * nodes is up to the caller.
   *
   * Values returned are either primitive types, 1IR nodes or a new vector of
   * nodes. The idea is to detach the structures of the 1IR and have a flat
   * representation for the specific types of nodes we need in each call.
   *
   * This is a static struct because we're declaring the functions directly on
   * the header (so we can use templates) and we don't want to end up with
   * duplicated definitions when included more than once. We also don't want
   * to make it super complex as it will go away some day in favour of a more
   * structured interface.
   */
  struct OneIR
  {
    /// Ast&MLIR independent path component
    struct NodePath
    {
      const std::string file;
      const size_t line;
      const size_t column;
    };
    /// Return the path of the 1IR node
    static NodePath getPath(SrcMgr mgr, BaseStmt* node)
    {
      auto loc = mgr.expand_source_location(node->source_range.first);
      return {loc.filename, loc.line, loc.column};
    }
  };

} // namespace mlir::verona
