
set(TESTNAME template_class)

add_llvm_executable(${TESTNAME} main.cc)
llvm_update_compile_flags(${TESTNAME})

target_link_libraries(${TESTNAME} PRIVATE
    clangAST
    clangASTMatchers
    clangAnalysis
    clangBasic
    clangCodeGen
    clangDriver
    clangEdit
    clangFrontend
    clangFrontendTool
    clangLex
    clangParse
    clangRewrite
    clangRewriteFrontend
    clangSema
    clangSerialization
    clangTooling
    clangCodeGen)

add_test(NAME ${TESTNAME} COMMAND ${TESTNAME} ${CMAKE_CURRENT_SOURCE_DIR}/"test.h")
add_dependencies(interop_tests ${TESTNAME})
