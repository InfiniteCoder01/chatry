pushd TwitchEventSub-rs/twitcheventsub-godot/
cargo build --release
popd
cp TwitchEventSub-rs/target/release/libtwitcheventsub_godot.so .
