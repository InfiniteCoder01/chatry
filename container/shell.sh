# docker run -v /mnt/Twitch:/home -v /mnt/Dev/Tools/build/orco/orco:/orco -it twitch-linux bash
docker run \
    -v /mnt/Twitch:/home \
    -v /mnt/Dev/Bots/Platforms/chatry/container/orco:/orco \
    -v /home/infinitecoder/Downloads/OrCo:/orco-src \
#     -v /mnt/Dev/Tools/build/orco/orco:/orco \
    -it twitch-linux bash
