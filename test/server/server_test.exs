defmodule P2PFileSharing.ServerTest do
  use ExUnit.Case, async: false

  alias P2PFileSharing.Server
  alias P2PFileSharing.FileInfo

  setup do
    {:ok, pid} = Server.start_link([])
    {:ok, pid: pid}
  end

  describe "init" do
    test "initializing the server", %{pid: pid} do
      assert Process.alive?(pid) == true
    end
  end

  describe "register" do
    test "registering a file without existing user" do
      Server.register("user1", "/path/to/file1")
      files = Server.get_files("user1")
      assert files == ["/path/to/file1"]
    end

    test "registering files without existing user" do
      Server.register("user1", "/path/to/file1, /path/to/file2")
      files = Server.get_files("user1")
      assert files == ["/path/to/file1", "/path/to/file2"]
    end

    test "registering file with existing user" do
      Server.register("user1", "/path/to/file1")
      Server.register("user1", "/path/to/file2")
      files = Server.get_files("user1")
      assert files == ["/path/to/file1", "/path/to/file2"]
    end

    test "registering files with existing user" do
      Server.register("user1", "/path/to/file1")
      Server.register("user1", "/path/to/file2, /path/to/file3")
      files = Server.get_files("user1")
      assert files == ["/path/to/file1", "/path/to/file2", "/path/to/file3"]
    end

    test "registering file with existing user and existing file" do
      Server.register("user1", "/path/to/file1")
      Server.register("user1", "/path/to/file1")
      files = Server.get_files("user1")
      assert files == ["/path/to/file1"]
    end

    test "registering files with existing user and existing file" do
      Server.register("user1", "/path/to/file1")
      Server.register("user1", "/path/to/file1, /path/to/file2")
      files = Server.get_files("user1")
      assert files == ["/path/to/file1", "/path/to/file2"]
    end

    test "registering files with existing user and existing files" do
      Server.register("user1", "/path/to/file1, /path/to/file2")
      Server.register("user1", "/path/to/file1, /path/to/file2, /path/to/file3")
      files = Server.get_files("user1")
      assert files == ["/path/to/file1", "/path/to/file2", "/path/to/file3"]
    end

    test "registering files with trailing spaces" do
      assert {:error, "Invalid format for files"} ==
               Server.register("user1", "/path/to/file1,  /path/to/file2 ")
    end

    test "registering files with leading spaces" do
      assert {:error, "Invalid format for files"} ==
               Server.register("user1", " /path/to/file1, /path/to/file2")
    end

    test "registering files cannot be nil" do
      assert {:error, "Files cannot be nil"} == Server.register("user1", nil)
    end

    test "registering files cannot be empty" do
      assert {:error, "Files cannot be empty"} == Server.register("user1", "")
    end

    test "registering file must be absolute path" do
      assert {:error, "Files must be absolute paths"} ==
               Server.register("user1", "path/to/file1")
    end
  end

  describe "unregister" do
    test "unregistering a file without existing user" do
      Server.unregister("user1", "/path/to/file1")
      files = Server.get_files("user1")
      assert files == []
    end

    test "unregistering files without existing user" do
      Server.unregister("user1", "/path/to/file1, /path/to/file2")
      files = Server.get_files("user1")
      assert files == []
    end

    test "unregistering file with existing user" do
      Server.register("user1", "/path/to/file1")
      Server.unregister("user1", "/path/to/file1")
      files = Server.get_files("user1")
      assert files == []
    end

    test "unregistering files with existing user" do
      Server.register("user1", "/path/to/file1, /path/to/file2")
      Server.unregister("user1", "/path/to/file1, /path/to/file2")
      files = Server.get_files("user1")
      assert files == []
    end

    test "unregistering file with existing user and existing file" do
      Server.register("user1", "/path/to/file1")
      Server.register("user1", "/path/to/file2")
      Server.unregister("user1", "/path/to/file1")
      files = Server.get_files("user1")
      assert files == ["/path/to/file2"]
    end

    test "unregistering files with existing user and existing file" do
      Server.register("user1", "/path/to/file1")
      Server.register("user1", "/path/to/file2, /path/to/file3")
      Server.unregister("user1", "/path/to/file1, /path/to/file2")
      files = Server.get_files("user1")
      assert files == ["/path/to/file3"]
    end

    test "unregistering files with existing user and existing files" do
      Server.register("user1", "/path/to/file1, /path/to/file2")
      Server.register("user1", "/path/to/file1, /path/to/file2, /path/to/file3")
      Server.unregister("user1", "/path/to/file1, /path/to/file2")
      files = Server.get_files("user1")
      assert files == ["/path/to/file3"]
    end

    # todo
    test "unregistering non-existing file" do
      Server.register("user1", "file2")
      assert :ok = Server.unregister("user1", "/path/to/file1")
    end

    test "unregistering non-existing user" do
      assert :ok = Server.unregister("user1", "/path/to/file1")
    end

    test "unregistering files with the corresponding user" do
      Server.register("user1", "/path/to/file1")
      Server.unregister("user1", "/path/to/file1")
      assert [] == Server.list_files()
    end
  end

  describe "user_correspondence" do
    test "get user correspondence in right format" do
      Server.register("user1", "/path/to/file1")
      Server.register("user2", "/path/to/file2")

      expected = [{"user1", {"127.0.0.1", 4040}}, {"user2", {"127.0.0.1", 4040}}]
      assert Enum.sort(expected) == Enum.sort(Server.get_user_correspondence())
    end
  end
end
