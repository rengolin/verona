// Copyright Microsoft and Project Verona Contributors.
// SPDX-License-Identifier: MIT

#include "../../CXXInterface.h"

#include <fstream>
#include <iomanip>
#include <iostream>

using namespace std;
using namespace verona::interop;
using namespace clang;
namespace cl = llvm::cl;

namespace
{
  /// Prints a type to stdout
  void printType(CXXType& ty)
  {
    assert(ty.valid());
    auto kind = ty.kindName();
    auto name = ty.getName().str();
    cout << name << "(@" << ty.decl << ") " << kind;
    if (ty.kind == CXXType::Kind::Builtin)
      cout << "(" << ty.builtinKindName() << ")";
    cout << endl;
  }

  /// Looks up a symbol from a CXX interface by name
  /// Tested on <array> looking for type "array"
  CXXType get_type(CXXInterface& interface, string& name)
  {
    auto ty = interface.getType(name);
    if (ty.valid())
    {
      cout << "Found: ";
      printType(ty);
    }
    else
    {
      cout << "Not found: " << name.c_str() << endl;
    }
    return ty;
  }

  /// Create the parameters of a template class from type names or values
  vector<TemplateArgument>
  create_template_args(CXXInterface& interface, llvm::ArrayRef<string> args)
  {
    vector<TemplateArgument> templateArgs;
    for (auto arg : args)
    {
      if (isdigit(arg[0]))
      {
        // Numbers default to int parameter
        auto num = atol(arg.c_str());
        templateArgs.push_back(interface.createTemplateArgumentForIntegerValue(
          CXXType::BuiltinTypeKinds::Int, num));
      }
      else
      {
        // Try to find the type name
        auto decl = interface.getType(arg);
        if (!decl.valid())
        {
          cerr << "Invalid template specialization type " << arg.c_str()
               << endl;
          exit(1);
        }
        templateArgs.push_back(interface.createTemplateArgumentForType(decl));
      }
    }
    return templateArgs;
  }

  /// Specialize the template into a CXXType
  CXXType specialize_template(
    CXXInterface& interface, CXXType& ty, llvm::ArrayRef<TemplateArgument> args)
  {
    // Canonical representation
    cout << "Canonical Template specialisation:" << endl;
    QualType canon =
      interface.getCanonicalTemplateSpecializationType(ty.decl, args);
    canon.dump();

    // Tries to instantiate a full specialisation
    return interface.instantiateClassTemplate(ty, args);
  }
} // namespace

int main(int argc, char** argv)
{
  vector<string> includePath = {};
  if (argc != 2)
  {
    cerr << "Missing argument <source file>" << endl;
    exit(1);
  }
  string file(argv[1]);

  // Create the C++ interface
  CXXInterface interface(file, includePath);

  string symbol = "Foo";
  vector<string> specialization{"int", "4"};
  auto req = specialization.size();

  // Query the requested symbol
  auto decl = get_type(interface, symbol);

  // Try and specialize a template
  // Make sure this is a template class
  if (!decl.isTemplate())
  {
    cerr << "Class " << symbol.c_str()
         << " is not a template class, can't specialize" << endl;
    exit(1);
  }

  // Make sure the number of arguments is the same
  auto has = decl.numberOfTemplateParameters();
  if (req != has)
  {
    cerr << "Requested " << req << " template arguments but class "
         << symbol.c_str() << " only has " << has << endl;
    exit(1);
  }

  // Specialize the template with the arguments
  auto args = create_template_args(interface, specialization);
  auto spec = specialize_template(interface, decl, args);
  cout << "Size of " << spec.getName().str().c_str() << " is "
       << interface.getTypeSize(spec) << " bytes" << endl;

  // Emit whatever is left on the main file
  auto mod = interface.emitLLVM();
  mod->dump();

  return 0;
}
