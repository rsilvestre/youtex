#!/usr/bin/env elixir

# Sample script to test Youtex functionality

# Use the MrBeast video as in the tests
video_id = "lxYFOM3UJzo" # Elixir: The Documentary

IO.puts("Testing Youtex.list_transcripts/1...")
case Youtex.list_transcripts(video_id) do
  {:ok, transcripts} ->
    IO.puts("✅ Success! Found #{length(transcripts)} transcripts")
    
    # Print first transcript details
    first = List.first(transcripts)
    IO.puts("First transcript: #{first.name} (#{first.language_code})")
    
    # Try getting English transcription
    IO.puts("\nTesting Youtex.get_transcription/2...")
    case Youtex.get_transcription(video_id, "en") do
      {:ok, transcript} ->
        IO.puts("✅ Success! Got transcript with #{length(transcript.sentences)} sentences")
        # Show first few sentences
        if length(transcript.sentences) > 0 do
          first_sentence = List.first(transcript.sentences)
          IO.puts("\nFirst sentence: \"#{first_sentence.text}\"")
        end
      
      {:error, reason} ->
        IO.puts("❌ Failed to get transcription: #{reason}")
    end
    
  {:error, reason} ->
    IO.puts("❌ Failed to list transcripts: #{reason}")
end