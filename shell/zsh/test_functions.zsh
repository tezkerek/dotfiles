#!/usr/bin/env zsh

source $(dirname $0)/functions.zsh

TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Test 1: mvp with missing dest parent creates it
mkdir -p $TEST_DIR/mvsrc
touch $TEST_DIR/mvsrc/file1 $TEST_DIR/mvsrc/file2
mvp $TEST_DIR/mvsrc/file1 $TEST_DIR/mvsrc/file2 $TEST_DIR/mvnew/a/b/
echo -n "Test 1 (mvp create parent): "
[[ -f $TEST_DIR/mvnew/a/b/file1 && -f $TEST_DIR/mvnew/a/b/file2 ]] && echo "PASS" || echo "FAIL"

# Test 2: mvp with trailing slash
touch $TEST_DIR/mvsrc/file3
mvp $TEST_DIR/mvsrc/file3 $TEST_DIR/mvnew/a/c/
echo -n "Test 2 (mvp trailing slash): "
[[ -f $TEST_DIR/mvnew/a/c/file3 ]] && echo "PASS" || echo "FAIL"

echo "All tests complete!"
