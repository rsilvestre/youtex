defmodule Youtex.Transcript.Parser do
  @moduledoc false

  use Youtex.Types
  alias Youtex.Transcript.Sentence

  @spec parse({:error, any()} | {:ok, String.t()}) :: sentence_list
  def parse({:ok, plain_data}) do
    plain_data
    |> xml_to_map()
    |> raw_sentences()
    |> to_sentences()
  end

  def parse({:error, _data}), do: []

  defp xml_to_map(plain_data) do
    # Handle empty or malformed XML gracefully
    case String.trim(plain_data) do
      "" ->
        # Empty response
        %{}
      
      trimmed_data ->
        # Try to parse the XML, catching any exceptions
        try do
          XmlToMap.naive_map(trimmed_data)
        catch
          :throw, {:error, _} ->
            # XML parsing failed (empty document or malformed)
            %{}
          
          :error, _ ->
            # Other parsing errors
            %{}
        end
    end
  end

  defp raw_sentences(%{"transcript" => %{"text" => sentences}}), do: sentences
  defp raw_sentences(_), do: []

  defp to_sentences(sentences) when is_list(sentences), do: Enum.map(sentences, &to_sentence/1)
  defp to_sentences(_), do: []

  defp to_sentence(%{"#content" => text, "-start" => start, "-dur" => duration}) do
    {start, _} = Float.parse(start)
    {duration, _} = Float.parse(duration)
    Sentence.new(text, start, duration)
  end
end
