defmodule P2PFileSharing.MiniServerTest do
  use ExUnit.Case

  # The test setup starts the MiniServer in a separate process and stops it after the test
  setup do
    {:ok, _pid} = P2PFileSharing.MiniServer.start("127.0.0.1", 4040)
    :ok
  end

  test "successfully downloads a file" do
    # Mocking the behavior of P2PFileSharing.Server.get_files/1
    P2PFileSharing.Server
    |> Kernel.def(:get_files, fn _user -> ["./test_file.txt"] end)

    # Connect to the MiniServer
    {:ok, socket} = :gen_tcp.connect("127.0.0.1", 4040, [:binary, {:packet, 0}, {:active, false}])

    # Send file request to MiniServer
    :gen_tcp.send(socket, {"test_user", "./test_file.txt"})

    # Receive the file
    {:ok, data} = :gen_tcp.recv(socket, 0)
    expected_data = File.read!("./test_file.txt")

    assert data == expected_data

    :gen_tcp.close(socket)
  end

  test "file not found returns appropriate error" do
    # Mocking the behavior of P2PFileSharing.Server.get_files/1
    P2PFileSharing.Server
    |> Kernel.def(:get_files, fn _user -> [] end)

    {:ok, socket} = :gen_tcp.connect("127.0.0.1", 4040, [:binary, {:packet, 0}, {:active, false}])

    :gen_tcp.send(socket, {"test_user", "./test_file.txt"})

    {:ok, data} = :gen_tcp.recv(socket, 0)
    assert data == "File not found"

    :gen_tcp.close(socket)
  end
end
