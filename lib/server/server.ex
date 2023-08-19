defmodule P2PFileSharing.Server do
  @docmodule """
  This module is responsible for storing the metadata for files that are shared by the users.
  """
  use GenServer
  alias P2PFileSharing.FileInfo

  @local_ip "127.0.0.1"
  @local_port 4040

  # GenServer callbacks
  @impl true
  def init(initial_state \\ []) do
    # it is possible to load the state from a file here about the files that are already shared
    # but what if these files are deleted locally? we would need to check if they still exist
    IO.puts("Server started")
    {:ok, initial_state}
  end

  @impl true
  def handle_cast({:register, user, files, ip, port}, state) do
    files_to_register = String.split(files, ", ")

    new_state =
      case find_user(user, state) do
        nil ->
          [FileInfo.new(user, files_to_register, ip, port) | state]

        %{path_to_file: existing_files} = record ->
          updated_record = %{
            record
            | path_to_file: existing_files ++ remove_duplicates(files_to_register, existing_files)
          }

          [updated_record | List.delete(state, record)]
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:unregister, user, files}, state) do
    files_to_unregister = String.split(files, ", ")

    new_state =
      case find_user(user, state) do
        nil ->
          state

        %{path_to_file: existing_files} = record ->
          updated_record = %{
            record
            | path_to_file: existing_files -- files_to_unregister
          }

          case updated_record.path_to_file do
            [] ->
              List.delete(state, record)

            _ ->
              [updated_record | List.delete(state, record)]
          end
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:add_user, user, ip, port}, state) do
    new_state =
      case find_user(user, state) do
        nil ->
          [FileInfo.new(user, [], ip, port) | state]

        _ ->
          state
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_user, user}, state) do
    new_state =
      case find_user(user, state) do
        nil ->
          state

        _ ->
          List.delete(state, find_user(user, state))
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:list_files, _from, state) do
    files =
      Enum.map(state, fn record ->
        {record.user, record.path_to_file}
      end)

    {:reply, files, state}
  end

  @impl true
  def handle_call({:get_files, user}, _from, state) do
    files =
      case find_user(user, state) do
        nil ->
          []

        record ->
          record.path_to_file
      end

    {:reply, files, state}
  end

  @impl true
  def handle_call(:get_user_correspondence, _from, state) do
    correspondence =
      Enum.map(state, fn record ->
        {record.user, {record.ip, record.port}}
      end)

    {:reply, correspondence, state}
  end

  @impl true
  def handle_call({:get_port, user}, _from, state) do
    port =
      case find_user(user, state) do
        nil ->
          nil

        record ->
          record.port
      end

    {:reply, port, state}
  end

  @impl true
  def handle_info(:timeout, state) do
    IO.puts("Timeout")
    {:noreply, state}
  end

  def start_link(_initial_state) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  # Public API functions
  @doc """
  Registers the files that are shared by the user. The files must be absolute paths.

  Example: P2PFileSharing.Server.register("user1", "/home/user1/file1.txt, /home/user1/file2.txt")
  > :ok
  """
  @spec register(String.t(), String.t(), String.t(), non_neg_integer()) ::
          :ok | {:error, String.t()}
  def register(user, files, ip \\ @local_ip, port \\ @local_port) do
    case validate_files(files) do
      {:error, reason} ->
        {:error, reason}

      :ok ->
        GenServer.cast(__MODULE__, {:register, user, files, ip, port})
    end
  end

  @doc """
  Unregisters the files that are shared by the user. The files must be absolute paths.

  Example: P2PFileSharing.Server.unregister("user1", "/home/user1/file1.txt, /home/user1/file2.txt")
  > :ok
  """
  @spec unregister(String.t(), String.t()) :: :ok | {:error, String.t()}
  def unregister(user, files) do
    case validate_files(files) do
      {:error, reason} ->
        {:error, reason}

      :ok ->
        GenServer.cast(__MODULE__, {:unregister, user, files})
    end
  end

  @doc """
  Returns a list of all the files that are shared by all the users.
  Format: [{user, [file1, file2, ...], ip, port}, ...]
  """
  @spec list_files() :: [FileInfo.t()]
  def list_files do
    GenServer.call(__MODULE__, :list_files)
  end

  @doc """
  Returns a list of all the files that are shared by the user.
  Format: [file1, file2, ...]
  """
  @spec get_files(String.t()) :: [String.t()]
  def get_files(user) do
    GenServer.call(__MODULE__, {:get_files, user})
  end

  @doc """
  Returns a list of all the users and their corresponding ip and port.
  Format: [{user, {ip, port}}, ...]
  """
  @spec get_user_correspondence() :: [
          {String.t(), {String.t(), non_neg_integer()}}
        ]
  def get_user_correspondence() do
    GenServer.call(__MODULE__, :get_user_correspondence)
  end

  @doc """
  Returns the port of the user.
  """
  @spec get_port(String.t()) :: non_neg_integer() | nil
  def get_port(user) do
    GenServer.call(__MODULE__, {:get_port, user})
  end

  @doc """
  Adds a new client that is connected to the server.
  """
  @spec add_user(String.t(), String.t(), non_neg_integer()) :: :ok | {:error, String.t()}
  def add_user(user, ip, port) do
    GenServer.cast(__MODULE__, {:add_user, user, ip, port})
  end

  @doc """
  Removes a client that is connected to the server.
  """
  @spec remove_user(String.t()) :: :ok | {:error, String.t()}
  def remove_user(user) do
    GenServer.cast(__MODULE__, {:remove_user, user})
  end

  # Private functions
  @spec find_user(String.t(), [FileInfo.t()]) :: FileInfo.t() | nil
  defp find_user(user, state) do
    Enum.find(state, fn %{user: username} -> username == user end)
  end

  @spec remove_duplicates([String.t()], [String.t()]) :: [String.t()]
  defp remove_duplicates(first, second) do
    first -- second
  end

  @spec validate_files(String.t()) :: :ok | {:error, String.t()}
  defp validate_files(nil), do: {:error, "Files cannot be nil"}
  defp validate_files(""), do: {:error, "Files cannot be empty"}

  defp validate_files(files) when is_binary(files) do
    case String.split(files, ", ") do
      [] ->
        {:error, "Files cannot be empty"}

      _ ->
        case whitespaces?(files) do
          true ->
            {:error, "Invalid format for files"}

          false ->
            case are_absolute_paths?(files) do
              true -> :ok
              false -> {:error, "Files must be absolute paths"}
            end
        end
    end
  end

  defp validate_files(_), do: {:error, "Invalid format for files"}

  @spec whitespaces?(String.t()) :: boolean()
  defp whitespaces?(string) do
    String.match?(string, ~r/\s{2,}|(?<=[^,])\s|^\s|\s$/)
  end

  @spec are_absolute_paths?(String.t()) :: boolean()
  defp are_absolute_paths?(files) do
    files
    |> String.split(", ")
    |> Enum.all?(fn file -> is_absolute_path?(file) end)
  end

  @spec is_absolute_path?(String.t()) :: boolean()
  defp is_absolute_path?(path) do
    # би трябвало да работи и за Windows
    String.match?(path, ~r{^\/|\w\:})
  end
end
