use std::io::{ Read, Write };
use std::process::Stdio;
use std::process::{ Child, Command };
use std::sync::mpsc::{ channel, Receiver, Sender };
use std::thread::{ self, JoinHandle };

use godot::engine::{ Engine, RefCounted };
use godot::prelude::*;

#[cfg(feature = "cdylib")]
struct BetterProcesses;
#[cfg(feature = "cdylib")]
#[gdextension]
unsafe impl ExtensionLibrary for BetterProcesses {}

#[derive(GodotClass)]
#[class(base = Node)]
pub struct ProcessNode {
    #[export]
    pub start_on_ready: bool,
    #[export]
    pub cmd: GString,
    #[export]
    pub args: PackedStringArray,

    raw_process: Option<RawProcess>,

    base: Base<Node>,
}

#[godot_api]
pub impl INode for ProcessNode {
    fn init(base: Base<Node>) -> Self {
        Self {
            start_on_ready: false,
            cmd: GString::from(""),
            args: PackedStringArray::new(),
            raw_process: None,
            base,
        }
    }
    fn ready(&mut self) {
        if Engine::singleton().is_editor_hint() {
            return;
        }
        if self.start_on_ready {
            self.start();
        }
    }
    fn process(&mut self, _delta: f64) {
        if let Some(mut raw_process) = self.raw_process.take() {
            let out = raw_process.read_stdout();
            if out.len() != 0 {
                self.base_mut().emit_signal(
                    "stdout".into(),
                    &[PackedByteArray::from_iter(out).to_variant()]
                );
            }
            let err = raw_process.read_stderr();
            if err.len() != 0 {
                self.base_mut().emit_signal(
                    "stderr".into(),
                    &[PackedByteArray::from_iter(err).to_variant()]
                );
            }
            self.raw_process = if raw_process.is_running() {
                Some(raw_process)
            } else {
                let a = raw_process.child.wait().unwrap().code().unwrap();
                self.base_mut().emit_signal("finished".into(), &[Variant::from(a)]);
                None
            };
        }
    }
}

#[godot_api]
pub impl ProcessNode {
    #[func]
    fn start(&mut self) {
        //start cmd
        let cmd = self.cmd.to_string();
        let args: Vec<String> = self.args
            .to_vec()
            .iter()
            .map(|i: &GString| i.to_string())
            .collect();
        let rp = RawProcess::new(cmd, args);
        self.raw_process = Some(rp);
    }

    #[func]
    fn write_stdin(&mut self, s: PackedByteArray) {
        match self.raw_process.take() {
            Some(rp) => {
                rp.write(s.to_vec().as_slice());
                self.raw_process = Some(rp);
            }
            _ => {
                godot_error!("Can't write to closed process!");
            }
        }
    }

    #[func]
    fn eof_stdin(&mut self) {
        match self.raw_process.take() {
            Some(mut rp) => {
                rp.eof();
                self.raw_process = Some(rp);
            }
            _ => {
                godot_error!("Can't write to closed process!");
            }
        }
    }

    // #[func]
    // fn qwer(&mut self){
    // }

    #[signal]
    fn stdout();
    #[signal]
    fn stderr();
    #[signal]
    fn finished(out:i32);
}

#[derive(GodotClass)]
#[class(base = RefCounted)]
pub struct Process {
    raw: Option<RawProcess>,
    _base: Base<RefCounted>,
}

#[godot_api]
pub impl INode for Process {
    fn init(base: Base<RefCounted>) -> Self {
        Self { raw: None, _base:base }
    }
}

#[godot_api]
pub impl Process {
    #[func]
    fn start(&mut self, cmd: GString, args: PackedStringArray) {
        let args: Vec<String> = args
            .to_vec()
            .iter()
            .map(|i: &GString| i.to_string())
            .collect();
        self.raw = Some(RawProcess::new(cmd.into(), args));
    }
    #[func]
    fn read_stdout(&mut self) -> PackedByteArray {
        todo!()
    }
    #[func]
    fn read_stderr(&mut self) -> PackedByteArray {
        todo!()
    }
    #[func]
    fn write_stdin(&mut self, _stdin: PackedByteArray) {
        todo!()
    }
    #[func]
    fn stdin_eof(&mut self) {
        todo!()
    }
    #[func]
    fn clear(&mut self) {
        todo!()
    }
    #[func]
    fn is_running(&mut self) -> bool {
        match &self.raw {
            Some(raw) => raw.is_running(),
            None => true,
        }
    }
}

struct RawProcess {
    stdin_tx: Option<Sender<u8>>,
    stdout_rx: Receiver<u8>,
    stderr_rx: Receiver<u8>,
    handle_stdout: JoinHandle<Result<(), String>>,
    _handle_stderr: JoinHandle<Result<(), String>>,
    _handle_stdin: JoinHandle<Result<(), String>>,
    child: Child,
}

impl RawProcess {
    fn new(cmd: String, args: Vec<String>) -> Self {
        let (stdout_tx, stdout_rx) = channel();
        let (stderr_tx, stderr_rx) = channel();
        let (stdin_tx, stdin_rx) = channel();
        let mut child = Command::new(cmd)
            .args(args)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .stdin(Stdio::piped())
            .spawn()
            .unwrap();

        let handle_stdout = {
            let stdout_tx = stdout_tx.clone();
            let stdout = child.stdout.take();
            thread::spawn(move || {
                match stdout {
                    Some(stdout) => {
                        for i in stdout.bytes() {
                            let _ = stdout_tx.send(i.unwrap());
                        }
                        Ok(())
                    }
                    None => Err("StdOut didn't init correctly".into()),
                }
            })
        };

        let handle_stdin = {
            let stdin = child.stdin.take();
            thread::spawn(move || {
                //this maybe needs to migrate to the above scope so we can process the handles correctly
                let mut a = stdin.unwrap();
                stdin_rx.iter().for_each(|v| {
                    let _ = a.write(&[v]);
                    let _ = a.flush(); //this pipe should throw Vec<Vec<u8>> and flush full Vec<u8> all at once
                });
                Ok(())
            })
        };

        let stderr = child.stderr.take();
        let stderr_tx = stderr_tx.clone();
        let handle_stderr = thread::spawn(move || {
            match stderr {
                Some(stderr) => {
                    for i in stderr.bytes() {
                        let _ = stderr_tx.send(i.unwrap());
                    }
                    Ok(())
                }
                None => Err("StdErr didn't init correctly".into()),
            }
        });

        Self {
            stdout_rx,
            stderr_rx,
            stdin_tx: Some(stdin_tx),
            handle_stdout,
            _handle_stderr: handle_stderr,
            _handle_stdin: handle_stdin,
            child,
        }
    }
    fn write(&self, text: &[u8]) {
        //should this be a str? u8 array?
        text.iter().for_each(|i| {
            let _ = self.stdin_tx.as_ref().expect("Can't send anything after EOF").send(*i);
        })
    }
    fn eof(&mut self) {
        self.stdin_tx = None;
    }
    fn read_stderr(&self) -> Vec<u8> {
        self.stderr_rx.try_iter().collect()
    }
    fn read_stdout(&self) -> Vec<u8> {
        self.stdout_rx.try_iter().collect()
    }
    fn is_running(&self) -> bool {
        self.handle_stdout.is_finished() == false
    }
}

impl Drop for RawProcess {
    fn drop(&mut self) {
        match self.child.kill() {
            Ok(_) => {}
            Err(_) => {} // sometimes the process already closed. gotta figure out detection
            // godot_error!("Failed to kill child process!"),
        }
    }
}
