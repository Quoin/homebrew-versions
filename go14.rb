class Go14 < Formula
  desc "Go programming environment (1.4)"
  homepage "https://golang.org"
  url "https://storage.googleapis.com/golang/go1.4.2.src.tar.gz"
  mirror "https://fossies.org/linux/misc/go1.4.2.src.tar.gz"
  version "1.4.2"
  sha256 "299a6fd8f8adfdce15bc06bde926e7b252ae8e24dd5b16b7d8791ed79e7b5e9b"

  bottle do
    sha256 "3fc0e4a72ea5e73da9b6c758da93c23a7ee07659f42a7caf379c2308064be615" => :yosemite
    sha256 "61bf4a9a6c6105fa2589d94945cedc22b5d05cf9ff0821bdc3308337d3d4106f" => :mavericks
    sha256 "6fc04d44d580a1e8c3b2689e4f403b417ccf65e258c40b8cf79ac2d0387552a7" => :mountain_lion
  end

  option "with-cc-all", "Build with cross-compilers and runtime support for all supported platforms"
  option "with-cc-common", "Build with cross-compilers and runtime support for darwin, linux and windows"
  option "without-cgo", "Build without cgo"
  option "without-godoc", "godoc will not be installed for you"
  option "without-vet", "vet will not be installed for you"

  deprecated_option "cross-compile-all" => "with-cc-all"
  deprecated_option "cross-compile-common" => "with-cc-common"

  resource "gotools" do
    url "https://go.googlesource.com/tools.git",
    :revision => "69db398fe0e69396984e3967724820c1f631e971"
  end

  resource "gobootstrap" do
    if MacOS.version > :lion
      url "https://storage.googleapis.com/golang/go1.4.2.darwin-amd64-osx10.8.tar.gz"
      sha256 "c2f53983fc8fe5159d811081022ebc401b8111759ce008f91193abdae82cdbc9"
    else
      url "https://storage.googleapis.com/golang/go1.4.2.darwin-amd64-osx10.6.tar.gz"
      sha256 "da40e85a2c9bda9d2c29755c8b57b8d5932440ba466ca366c2a667697a62da4c"
    end
  end

  def install
    # host platform (darwin) must come last in the targets list
    if build.with? "cc-all"
      targets = [
        ["linux",   ["386", "amd64", "arm"]],
        ["freebsd", ["386", "amd64", "arm"]],
        ["netbsd",  ["386", "amd64", "arm"]],
        ["openbsd", ["386", "amd64"]],
        ["windows", ["386", "amd64"]],
        ["dragonfly", ["386", "amd64"]],
        ["plan9",   ["386", "amd64"]],
        ["solaris", ["amd64"]],
        ["darwin",  ["386", "amd64"]],
      ]
    elsif build.with? "cc-common"
      targets = [
        ["linux",   ["386", "amd64", "arm"]],
        ["windows", ["386", "amd64"]],
        ["darwin",  ["386", "amd64"]],
      ]
    else
      targets = [["darwin", [""]]]
    end

    cd "src" do
      targets.each do |os, archs|
        cgo_enabled = os == "darwin" && build.with?("cgo") ? "1" : "0"
        archs.each do |arch|
          ENV["GOROOT_FINAL"] = libexec
          ENV["GOOS"]         = os
          ENV["GOARCH"]       = arch
          ENV["CGO_ENABLED"]  = cgo_enabled
          ohai "Building go for #{arch}-#{os}"
          system "./make.bash", "--no-clean"
        end
      end
    end

    (buildpath/"pkg/obj").rmtree
    rm_rf "gobootstrap" # Bootstrap not required beyond compile.
    libexec.install Dir["*"]
    (bin/"go14").write_env_script(libexec/"bin/go", :PATH => "#{libexec}/bin:$PATH")
    bin.install_symlink libexec/"bin/gofmt" => "gofmt14"

    if build.with?("godoc") || build.with?("vet")
      ENV.prepend_path "PATH", libexec/"bin"
      ENV["GOPATH"] = buildpath
      (buildpath/"src/golang.org/x/tools").install resource("gotools")

      if build.with? "godoc"
        cd "src/golang.org/x/tools/cmd/godoc/" do
          system "go", "build"
          (libexec/"bin").install "godoc"
        end
        bin.install_symlink libexec/"bin/godoc" => "godoc14"
      end

      if build.with? "vet"
        cd "src/golang.org/x/tools/cmd/vet/" do
          system "go", "build"
          # This is where Go puts vet natively; not in the bin.
          (libexec/"pkg/tool/darwin_amd64/").install "vet"
        end
      end
    end
  end

  def caveats; <<-EOS.undent
    The `go*` commands in `bin` are suffixed with 14 e.g. `go14`.

    As of go 1.2, a valid GOPATH is required to use the `go get` command:
      https://golang.org/doc/code.html#GOPATH

    You may wish to add the GOROOT-based install location
    (with unsuffixed `go*` commands) to your PATH:
      export PATH=$PATH:#{opt_libexec}/bin
    EOS
  end

  test do
    (testpath/"hello.go").write <<-EOS.undent
    package main

    import "fmt"

    func main() {
        fmt.Println("Hello World")
    }
    EOS
    # Run go fmt check for no errors then run the program.
    # This is a a bare minimum of go working as it uses fmt, build, and run.
    system "#{bin}/go14", "fmt", "hello.go"
    assert_equal "Hello World\n", shell_output("#{bin}/go14 run hello.go")

    if build.with? "godoc"
      assert File.exist?(libexec/"bin/godoc")
      assert File.executable?(libexec/"bin/godoc")
    end

    if build.with? "vet"
      assert File.exist?(libexec/"pkg/tool/darwin_amd64/vet")
      assert File.executable?(libexec/"pkg/tool/darwin_amd64/vet")
    end
  end
end
