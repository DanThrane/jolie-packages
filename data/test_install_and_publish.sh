. assert.sh
cd dummy_package
assert_raises "jpm register foo bar"
assert "jpm whoami" "foo"
assert_raises "jpm publish"
cd ../target
rm -rf jpm_packages
assert_raises "jpm install"
assert_raises "jpm logout"
assert_raises "jpm whoami" 400
assert_raises "jpm install" 400
assert_end 
