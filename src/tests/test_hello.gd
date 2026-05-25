extends GdUnitTestSuite


func test_basic_math() -> void:
	assert_int(1 + 1).is_equal(2)
