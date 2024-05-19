use super::*;

impl State {
    pub fn compile_and_run(&mut self, cmd: &str) {
        match async_process::Command::new("podman")
            .arg("run")
            .arg("-v")
            .arg("/mnt/Twitch:/home:Z")
            .arg("-w")
            .arg("/home")
            .arg("--cpus")
            .arg("1")
            .arg("--memory")
            .arg("20m")
            .arg("-i")
            .arg("twitch-linux")
            .arg("./compile.sh")
            .stdin(async_process::Stdio::piped())
            .stdout(async_process::Stdio::piped())
            .stderr(async_process::Stdio::piped())
            .spawn()
        {
            Ok(mut shell) => {
                let mut stdin = shell.stdin.take().unwrap();
                let cmd = cmd.to_owned();
                self.runtime.spawn(async move {
                    if let Err(err) = stdin.write_all(cmd.as_bytes()).await {
                        log::error!("Error: {}", err);
                    }
                });
                let mut stdout = futures::io::BufReader::new(shell.stdout.take().unwrap()).lines();
                let stdout_tty = self.tty.clone();
                self.runtime.spawn(async move {
                    while let Some(line) = stdout.next().await {
                        if let Ok(line) = line {
                            println!("{}", line);
                            stdout_tty.lock().unwrap().push(line);
                        }
                    }
                });
                let mut stderr = futures::io::BufReader::new(shell.stderr.take().unwrap()).lines();
                let stderr_tty = self.tty.clone();
                self.runtime.spawn(async move {
                    while let Some(line) = stderr.next().await {
                        if let Ok(line) = line {
                            eprintln!("{}", line);
                            stderr_tty.lock().unwrap().push(line);
                        }
                    }
                });
            }
            Err(err) => self
                .tty
                .lock()
                .unwrap()
                .push(format!("Failed to spawn shell: {}!", err)),
        }
    }
}
