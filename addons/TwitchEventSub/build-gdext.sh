pushd TwitchEventSub-rs/TwitchEventSub-Godot/
cargo build --release
popd
cp TwitchEventSub-rs/TwitchEventSub-Godot/target/release/libtwitchevents_godot.so .
