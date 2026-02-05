# MOS Notes 2/4

### Coroutines

```C++
lazy<int> f(long n) {
  if (n == 0){
    co_return 1;
  } else {
    co_return n * co_await f(n-1);
  }
}
```

Compiler:  
Instead of allocating a stack frame for a function call, create a struct holding the function's state

If the function can't make progress, it can "return" to the caller with `co_await`. The struct continues to live, so the function can be resumed later. Struct contains point to resume at. 

User:  
Creates promise type that is returned by coroutine

Compiler generates handle to connect promise to function struct


