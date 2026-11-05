extends GutTest


func test_new_pool_starts_empty() -> void:
	var pool := IdPool.new(3)
	assert_eq(pool.capacity, 3)
	assert_eq(pool.available_count(), 3)
	assert_eq(pool.active_count(), 0)
	assert_false(pool.is_full())
	assert_false(pool.is_allocated(0))


func test_acquire_returns_ascending_ids() -> void:
	var pool := IdPool.new(3)
	assert_eq(pool.acquire(), 0)
	assert_eq(pool.acquire(), 1)
	assert_eq(pool.acquire(), 2)
	assert_eq(pool.available_count(), 0)
	assert_eq(pool.active_count(), 3)
	assert_true(pool.is_full())


func test_acquire_when_full_returns_invalid_id() -> void:
	var pool := IdPool.new(1)
	assert_eq(pool.acquire(), 0)
	assert_eq(pool.acquire(), IdPool.INVALID_ID)
	assert_eq(pool.active_count(), 1)


func test_release_makes_id_available_again() -> void:
	var pool := IdPool.new(3)
	assert_eq(pool.acquire(), 0)
	assert_eq(pool.acquire(), 1)
	assert_true(pool.release(0))
	assert_false(pool.is_allocated(0))
	assert_true(pool.is_allocated(1))
	assert_eq(pool.active_count(), 1)
	# Released IDs are reused first (LIFO).
	assert_eq(pool.acquire(), 0)
	assert_true(pool.is_allocated(0))


func test_release_rejects_double_release() -> void:
	var pool := IdPool.new(2)
	var id: int = pool.acquire()
	assert_true(pool.release(id))
	assert_false(pool.release(id))
	assert_eq(pool.available_count(), 2)
	assert_eq(pool.acquire(), id)
	assert_eq(pool.acquire(), 1)
	assert_eq(pool.acquire(), IdPool.INVALID_ID)


func test_release_rejects_invalid_and_unallocated_ids() -> void:
	var pool := IdPool.new(3)
	assert_false(pool.release(-1))
	assert_false(pool.release(3))
	assert_false(pool.release(99))
	assert_false(pool.release(0))
	assert_eq(pool.available_count(), 3)


func test_is_allocated_checks_bounds() -> void:
	var pool := IdPool.new(2)
	assert_false(pool.is_allocated(-1))
	assert_false(pool.is_allocated(2))
	assert_false(pool.is_allocated(999))
	var id: int = pool.acquire()
	assert_true(pool.is_allocated(id))
	assert_true(pool.release(id))
	assert_false(pool.is_allocated(id))


func test_reset_releases_everything_and_restores_id_order() -> void:
	var pool := IdPool.new(3)
	pool.acquire()
	pool.acquire()
	pool.reset()
	assert_eq(pool.active_count(), 0)
	assert_eq(pool.available_count(), 3)
	assert_false(pool.is_full())
	assert_false(pool.is_allocated(0))
	assert_false(pool.is_allocated(1))
	assert_eq(pool.acquire(), 0)
	assert_eq(pool.acquire(), 1)
	assert_eq(pool.acquire(), 2)


func test_multiple_release_and_reuse_cycles() -> void:
	var pool := IdPool.new(2)
	for cycle in range(10):
		var a: int = pool.acquire()
		var b: int = pool.acquire()
		assert_ne(a, b)
		assert_true(pool.is_full())
		assert_true(pool.release(a))
		assert_true(pool.release(b))
		assert_eq(pool.active_count(), 0)
		assert_eq(pool.available_count(), 2)
