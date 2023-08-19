defmodule P2PFileSharing.FileInfo do
  @type t :: %__MODULE__{
          user: String.t(),
          path_to_file: [String.t()],
          ip: String.t(),
          port: non_neg_integer()
        }

  @type user :: String.t()
  @type path_to_file :: [String.t()]
  @type ip :: String.t()

  defstruct user: "", path_to_file: [], ip: "", port: 0

  @spec new(
          user :: String.t(),
          path_to_file :: [String.t()],
          ip :: String.t(),
          port :: non_neg_integer()
        ) :: t()
  def new(user, path_to_file, ip, port) do
    %__MODULE__{
      user: user,
      path_to_file: path_to_file,
      ip: ip,
      port: port
    }
  end
end
