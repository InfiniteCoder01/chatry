use super::*;

pub struct YouTubeChat {
    runtime: Arc<tokio::runtime::Runtime>,
    client: Option<
        Arc<google_youtube3::YouTube<hyper_rustls::HttpsConnector<hyper::client::HttpConnector>>>,
    >,
    receiver: std::sync::mpsc::Receiver<MessageContent>,
}

impl YouTubeChat {
    pub fn new(
        runtime: Arc<tokio::runtime::Runtime>,
        credentials_path: &std::path::Path,
        config: &'static Config,
    ) -> Self {
        let (transmitter, receiver) = std::sync::mpsc::channel::<api::MessageContent>();
        let credentials_path = credentials_path.to_path_buf();

        macro_rules! unwrap_or_log {
            ($e:expr, $or_else: expr) => {
                match $e {
                    Ok(v) => v,
                    Err(e) => {
                        log::error!("{}", e);
                        $or_else
                    }
                }
            };
        }

        let client = runtime.block_on(async move {
            use google_youtube3::oauth2;
            let secret = unwrap_or_log!(
                serde_json::from_str::<oauth2::ConsoleApplicationSecret>(&unwrap_or_log!(
                    std::fs::read_to_string(credentials_path),
                    return None
                )),
                return None
            );
            let auth = unwrap_or_log!(
                oauth2::InstalledFlowAuthenticator::builder(
                    unwrap_or_log!(
                        secret
                            .installed
                            .or(secret.web)
                            .ok_or("No credentials in the credentials file"),
                        return None
                    ),
                    oauth2::InstalledFlowReturnMethod::HTTPRedirect,
                )
                // .with_storage(Box::new(KeyringTokenStorage))
                .build()
                .await,
                return None
            );
            let client = google_youtube3::YouTube::new(
                hyper::Client::builder().build(
                    hyper_rustls::HttpsConnectorBuilder::new()
                        .with_native_roots()
                        .https_or_http()
                        .enable_http1()
                        .build(),
                ),
                auth,
            );
            Some(Arc::new(client))
        });
        let reader_thread_client = client.clone();
        runtime.spawn(async move {
            let live_chat_id = Mutex::new(None);
            let live_broadcast_id = Mutex::new(None);
            let mut anonymous_client = youtube_chat::live_chat::LiveChatClientBuilder::new()
                .channel_id(config.youtube_channel.clone())
                .on_start(|broadcast_id| {
                    *live_broadcast_id.lock().unwrap() = Some(broadcast_id);
                })
                .on_chat(|chat_item| {
                    unwrap_or_log!(
                        transmitter.send(api::MessageContent::new(
                            Some(chat_item.id),
                            live_chat_id
                                .lock()
                                .unwrap()
                                .clone()
                                .unwrap_or(String::new()),
                            chat_item
                                .author
                                .name
                                .unwrap_or(format!("@{}", chat_item.author.channel_id)),
                            Rgba::opaque(1.0, 0.5, 0.5),
                            chat_item
                                .message
                                .into_iter()
                                .fold(String::new(), |mut acc, msg| {
                                    use youtube_chat::item::MessageItem;
                                    match msg {
                                        MessageItem::Text(msg) => acc.push_str(&msg),
                                        MessageItem::Emoji(emoji) => acc.push_str(
                                            &emoji.emoji_text.unwrap_or("<Emote>".to_owned()),
                                        ),
                                    }
                                    acc
                                })
                        )),
                        ()
                    );
                })
                .on_error(|error| {
                    log::error!("{}", error);
                    *live_chat_id.lock().unwrap() = None;
                })
                .build();
            let mut interval = tokio::time::interval(tokio::time::Duration::from_millis(1000));
            loop {
                interval.tick().await;
                if let (Some(broadcast_id), Some(client)) = (
                    {
                        let broadcast_id = live_broadcast_id.lock().unwrap();
                        broadcast_id.clone()
                    },
                    reader_thread_client.clone(),
                ) {
                    let broadcasts = unwrap_or_log!(
                        client
                            .live_broadcasts()
                            .list(&vec!["snippet".to_owned()])
                            .add_id(&broadcast_id)
                            .doit()
                            .await,
                        return
                    )
                    .1;
                    let broadcasts = unwrap_or_log!(
                        broadcasts
                            .items
                            .ok_or("Respnonce doesn't contain broadcast data"),
                        return
                    );
                    let broadcast = unwrap_or_log!(
                        broadcasts.into_iter().next().ok_or("No broadcasts found"),
                        return
                    );
                    let snippet = unwrap_or_log!(
                        broadcast
                            .snippet
                            .ok_or("Broadcast doesn't contain snippet data"),
                        return
                    );
                    *live_chat_id.lock().unwrap() = Some(unwrap_or_log!(
                        snippet
                            .live_chat_id
                            .ok_or("Broadcast doesn't contain live chat id"),
                        return
                    ));
                    *live_broadcast_id.lock().unwrap() = None;
                }

                let Some(_live_chat_id) = ({
                    let live_chat_id = live_chat_id.lock().unwrap();
                    live_chat_id.clone()
                }) else {
                    unwrap_or_log!(anonymous_client.start().await, ());
                    continue;
                };
                anonymous_client.execute().await;
            }
        });
        Self {
            runtime,
            client,
            receiver,
        }
    }
}

impl LiveChat for YouTubeChat {
    fn send(&mut self, stream_id: &str, message: &str) {
        if let Some(client) = &self.client {
            self.runtime.block_on(async {
                let msg = google_youtube3::api::LiveChatMessage {
                    snippet: Some(google_youtube3::api::LiveChatMessageSnippet {
                        live_chat_id: Some(stream_id.to_owned()),
                        type_: Some("textMessageEvent".to_owned()),
                        text_message_details: Some(
                            google_youtube3::api::LiveChatTextMessageDetails {
                                message_text: Some(message.to_owned()),
                            },
                        ),
                        ..Default::default()
                    }),
                    ..Default::default()
                };
                if let Err(err) = client
                    .live_chat_messages()
                    .insert(msg)
                    .add_part("snippet")
                    .doit()
                    .await
                {
                    log::error!("{}", err);
                }
            });
        }
    }

    fn reply(&mut self, stream_id: &str, _to_id: &str, author: &str, message: &str) {
        self.send(stream_id, &format!("@{} {}", author, message));
    }

    fn next(&mut self) -> Option<Message> {
        match self.receiver.try_recv() {
            Ok(msg) => Some(Message {
                channel: Some(self),
                content: msg,
            }),
            Err(err) => match err {
                std::sync::mpsc::TryRecvError::Empty => None,
                std::sync::mpsc::TryRecvError::Disconnected => {
                    log::error!("Youtube channel disconnected");
                    None
                }
            },
        }
    }
}

pub struct KeyringTokenStorage;

impl KeyringTokenStorage {
    pub async fn store(&self, key: impl ToString, value: String) -> anyhow::Result<()> {
        let entry = keyring::KeyringEntry::try_new(key)?;
        entry
            .set_secret(value)
            .await
            .map_err(|e| anyhow::anyhow!(e))
    }

    pub async fn retrieve(&self, key: impl ToString) -> anyhow::Result<String> {
        let entry = keyring::KeyringEntry::try_new(key)?;
        entry.get_secret().await.map_err(|e| anyhow::anyhow!(e))
    }
}

impl google_youtube3::oauth2::storage::TokenStorage for KeyringTokenStorage {
    fn set<'life0, 'life1, 'life2, 'async_trait>(
        &'life0 self,
        scopes: &'life1 [&'life2 str],
        token: google_youtube3::oauth2::storage::TokenInfo,
    ) -> ::core::pin::Pin<
        Box<
            dyn ::core::future::Future<Output = anyhow::Result<()>>
                + ::core::marker::Send
                + 'async_trait,
        >,
    >
    where
        'life0: 'async_trait,
        'life1: 'async_trait,
        'life2: 'async_trait,
        Self: 'async_trait,
    {
        Box::pin(async move {
            self.store(scopes.join("::"), serde_json::to_string(&token)?)
                .await
        })
    }

    fn get<'life0, 'life1, 'life2, 'async_trait>(
        &'life0 self,
        scopes: &'life1 [&'life2 str],
    ) -> ::core::pin::Pin<
        Box<
            dyn ::core::future::Future<Output = Option<google_youtube3::oauth2::storage::TokenInfo>>
                + ::core::marker::Send
                + 'async_trait,
        >,
    >
    where
        'life0: 'async_trait,
        'life1: 'async_trait,
        'life2: 'async_trait,
        Self: 'async_trait,
    {
        Box::pin(async move {
            match self
                .retrieve(scopes.join("::"))
                .await
                .and_then(|token| serde_json::from_str(&token).map_err(|e| anyhow::anyhow!(e)))
            {
                Ok(token) => Some(token),
                Err(err) => {
                    log::error!("Failed to load token: {}", err);
                    None
                }
            }
        })
    }
}
