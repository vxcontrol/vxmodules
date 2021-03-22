--[[1]]
foo = {}
foo.key = 'value'

--[[2]]
mt = {__index = foo}

-- setmetatable возвращает первый переданный в неё аргумент
--[[3]] 
bar = setmetatable({}, mt)
bar.key2 = 'value2'


-- Тестирование:

--[[4]] 
print('bar.key2', bar.key2) --> 'value2'

--[[5]] 
print('bar.key', bar.key) --> 'value'

--[[6]]
bar.key = 'foobar'
foo.foo = 'snafu'
print('foo.key', foo.key) --> 'value'
print('bar.key', bar.key) --> 'foobar'
print('bar.foo', bar.foo) --> 'snafu'
print('bar.foobarsnafu', bar.foobarsnafu) --> nil


--[[7]]
one   = {t = function(a) return a end}
foo   = {key = 'FooBar', name_foo = 'foo'}
bar   = {key = 'BarFoo', name_bar = 'bar'}

-- так тоже можно
snafu = setmetatable(one, {__index = foo})
print('1 snafu.key', snafu.key) --> 'FooBar'
print('1 snafu.t', snafu.t("123")) --> '123'
snafu = setmetatable(snafu, {__index = bar})
print('2 snafu.key', snafu.key) --> 'FooBar'
print('2 snafu.t', snafu.t("123")) --> '123'


--[[8]]
foo = {}
foo.__index = foo
setmetatable(foo, foo)

-- print('foo.key',         foo.key)            --> error: loop in gettable

print('foo.__index',        foo.__index)        --> "table: 0x12345678"
print('rawget(foo, "key")', rawget(foo, "key")) --> nil

--[[9]]
foo = {}
foo.key = 'value'
setmetatable(foo, {__index = function(self, key) return key end})

print('foo.key', foo.key) --> 'value'
print('foo.value', foo.value) --> 'value'
print('foo.snafu', foo.snafu) --> 'snafu'


--[[10]]
fibs = { 1, 1 }
print(fibs)
t = setmetatable(fibs, { 
  __index = function(self, v)
    self[v] = self[v - 1] + self[v - 2]
    return self[v]
  end
})

print(fibs[8], t, fibs)

-----------------------------------
mt = {}
mt.id = 12345

foo = setmetatable({}, mt)

print(foo.id) --> nil
print(getmetatable(foo).id) --> 12345

-----------------------------------
mt = {}
function mt.__gc(self)
  print('Table '..tostring(self)..' has been destroyed!')
end

-- lua 5.2+
foo = {id = "test id"}
setmetatable(foo, mt)

-- Lua 5.1
if _VERSION == 'Lua 5.1' then
	-- Метаметод __gc работает в 5.1 только по отношению к cdata-типам.
	-- Данная методика - грязный хак, но иногда полезен.
	
	-- мы будем удалять ссылку 'foo', тут локальная копия
	local t = foo
	
	-- newproxy возвращает cdata-указатель, недокументированная функция Lua 5.1.
	local proxy = newproxy(true)
	
	-- метаметод __gc данной cdata - вызов __gc-метаметода таблицы foo
	getmetatable(proxy).__gc = function(self) mt.__gc(t) end
	
	foo[proxy] = true
end	

require'inspect'(foo)
print(foo)
foo = nil

collectgarbage()


require'yaci'

function get_class()
local A = newclass("A")

function A:init(a_data)
  print("exec A init: ", a_data)
  self.a_data = a_data
  self.foo = nil
end

function A:setFoo(foo)
  print("Exec setFoo: ", self)
  require'inspect'(foo)
  self.foo = foo
end

function A:free()
  print("exec A free")
  if self.foo then self.foo = nil end
end

local B = newclass("B", A)

function B:init(a_data, b_data)
  print("exec B init: ", a_data, b_data)
  self.super:init(a_data)
  self.b_data = b_data
  
  mt = {}
  function mt.__gc(self)
    print('Table has been destroyed!')
  end
  local foo = setmetatable({'some', 'values', 'here'}, mt)
  if _VERSION == 'Lua 5.1' then
    local destructor = newproxy(true)
    getmetatable(destructor).__gc = function(self) mt.__gc() end
    rawset(foo, destructor, true)
  end
  
  self.b_table = foo
end

function B:free()
  print("exec B free")
  self.b_table = nil
  if self.foo then print("self.foo still exists!!!") end
end

local C = newclass("C", B)

function C:init(a_data, b_data)
  print("exec C init: ", a_data, b_data)
  self.super:init(a_data, b_data)
  self.b_data = b_data
end

function C:free()
  print("exec C free")
end

return C
end

-- and now some calls
local myC = get_class()("a_data2", "b_data")

print("Object foo: ", myC.foo)
print("before exec setFoo")
myC:setFoo({'some', 'more', 'values'})
print("after exec setFoo")
print("Object foo: ", myC.foo)

--require'inspect'(myC)
collectgarbage()
print("before destroy C", collectgarbage"count" * 1024)
myC = nil
collectgarbage()
print("after destroy C", collectgarbage"count" * 1024)
collectgarbage()

print("finish")
-- will print "self.foo still exists" !!!




A = newclass("A")

function A:init()
  self.x = 42  -- define an attribute here for internal purposes
end

function A:doSomething()
  self.x = 0   -- change attribute value
  -- do something here...
end


B = newclass("B", A)

function B:init(x)
  self.x = x          -- B defines a private 'x' attribute
  self.super:init()   -- call the superclass's constructor
end

function B:doYourJob()
  self.x = 5
  self:doSomething()
  print(self.x)       -- prints "5": 'x' has not been modified by A
  print(self.super.x) -- prints "0": this is the 'x' attribute that was used by A
end

b = B(10)
print(b.x)
b:doYourJob()


A = newclass("A")

function A:foo()
  print(self.x)         -- prints "nil"! There is no field 'x' at A's level
  selfB = B:cast(self)  -- explicit casting into a B
  print(selfB.x)        -- prints "5"
end


B = newclass("B",A)

function B:init(x) 
	self.x = x
end

myB = B(5)
myB:foo()


A = newclass("A")

function A:whoami()
  return "A"
end
A:virtual("whoami") -- whoami() is declared virtual

function A:test()
  print(self:whoami())
end

B = newclass("B", A)

function B:whoami()
  return "B"
end
  -- no need to use B:virtual() here
  
myB = B()
myB:test() -- prints "B"

A = newclass("A")
function A:init(a) self.a = a end
A.test = 5   -- a static variable in A

a = A(3)
print(a.a)           -- prints 3
print(a.test)        -- prints 5
a.test = 7
print(a.test)        -- prints 7
print(A.test)        -- prints nil (!)
print(A.static.test) -- prints 5
