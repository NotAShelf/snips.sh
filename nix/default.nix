{
  lib,
  buildGoModule,
  fetchFromGitHub,
  libtensorflow,
  ...
}:
buildGoModule rec {
  pname = "snips-sh";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "robherley";
    repo = "snips.sh";
    rev = "v${version}";
    hash = "sha256-0aoLIxoXafEygoSo/GLsP6kYQnAhFu6YJuit/gyeg+c=";
  };

  buildInputs = [
    libtensorflow
  ];

  vendorHash = "sha256-BZpiFD5b0TbvUYjDaXEs17VwRQfRsY4GnbYu7DtXaY0=";

  ldflags = ["-s" "-w"];

  meta = with lib; {
    description = "Passwordless, anonymous SSH-powered pastebin with a human-friendly TUI and web UI";
    homepage = "https://github.com/robherley/snips.sh";
    license = licenses.mit;
    maintainers = with maintainers; [NotAShelf];
    mainProgram = "snips.sh";
  };
}
