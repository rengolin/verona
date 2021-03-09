// Copyright Microsoft and Project Verona Contributors.
// SPDX-License-Identifier: MIT

template<class T, int num = 4>
struct Foo
{
  T innerFoo;
  T add(T arg)
  {
    return arg + innerFoo + num;
  }
};

int foo()
{
  Foo<int> F;
  F.innerFoo = 3;
  return F.add(4);
}
