pushd TwitchEventSub-rs/twitcheventsub-godot/
cargo build --release && cp ../target/release/libtwitcheventsub_godot.so ../../
popd
