use geng::prelude::*;
use youtube_chat::{item::ChatItem, live_chat::Empty};

pub struct MessageTransferer(pub std::sync::mpsc::Sender<ChatItem>);

impl Fn<(ChatItem,)> for MessageTransferer {
    extern "rust-call" fn call(&self, (message,): (ChatItem,)) -> Self::Output {
        if let Err(error) = self.0.send(message) {
            log::error!("Failed to transfer youtube message: {}!", error);
        }
    }
}

impl FnMut<(ChatItem,)> for MessageTransferer {
    extern "rust-call" fn call_mut(&mut self, args: (ChatItem,)) -> Self::Output {
        self.call(args)
    }
}

impl FnOnce<(ChatItem,)> for MessageTransferer {
    type Output = ();
    extern "rust-call" fn call_once(self, args: (ChatItem,)) -> Self::Output {
        self.call(args)
    }
}

pub struct ErrorHandler;

impl Fn<(anyhow::Error,)> for ErrorHandler {
    extern "rust-call" fn call(&self, (error,): (anyhow::Error,)) -> Self::Output {
        log::error!("Youtube IRC error: {}!", error);
    }
}

impl FnMut<(anyhow::Error,)> for ErrorHandler {
    extern "rust-call" fn call_mut(&mut self, args: (anyhow::Error,)) -> Self::Output {
        self.call(args)
    }
}

impl FnOnce<(anyhow::Error,)> for ErrorHandler {
    type Output = ();
    extern "rust-call" fn call_once(self, args: (anyhow::Error,)) -> Self::Output {
        self.call(args)
    }
}

pub type YoutubeClient =
    youtube_chat::live_chat::LiveChatClient<Empty, Empty, MessageTransferer, ErrorHandler>;
pub type YoutubeReciever = std::sync::mpsc::Receiver<ChatItem>;

pub fn init(mut client: YoutubeClient) -> (YoutubeClient, bool) {
    tokio_async(async move {
        if let Err(err) = client.start().await {
            log::error!("Failed to start youtube IRC: {}", err);
            (client, false)
        } else {
            (client, true)
        }
    })
}

fn tokio_async<T: Send>(future: impl Future<Output = T> + Send) -> T {
    tokio::runtime::Runtime::new().unwrap().block_on(future)
}
