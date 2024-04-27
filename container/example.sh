echo 'extern fn puts(message: char*); fn main() -> i32 { puts(c"Hello, World!"); return 0; }' | ./compile.sh
