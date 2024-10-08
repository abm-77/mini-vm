{
  description = "template";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: 
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
        inherit system;
    };
    deps = with pkgs; [ 
      git
      gnumake
      ncurses
      bc
      flex
      bison
      elfutils
      openssl
      qemu_full
      debootstrap
      pciutils
      autoconf
      libiberty
      udev
      sshpass
      musl
    ];
  in 
  {
    devShells."${system}" =  {
      default = pkgs.mkShell.override
      {}
      {
        packages = deps;
      };
    };
  };  
}
