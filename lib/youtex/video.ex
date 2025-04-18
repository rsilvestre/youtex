defmodule Youtex.Video do
  @moduledoc """
  The module do create and to hold Youtube's video information.
  """

  @base_url "https://www.youtube.com/watch?v="

  use Youtex.Types
  use TypedStruct

  typedstruct enforce: true do
    field :id, video_id
    field :url, String.t()
  end

  def new(id) do
    struct!(__MODULE__, id: id, url: @base_url <> id)
  end
end
