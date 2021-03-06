--
-- Test suite for stream encoder.
--
-- Copyright © 2016–2017 Mark Karpov <markkarpov@openmailbox.org>
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are
-- met:
--
-- * Redistributions of source code must retain the above copyright notice,
--   this list of conditions and the following disclaimer.
--
-- * Redistributions in binary form must reproduce the above copyright
--   notice, this list of conditions and the following disclaimer in the
--   documentation and/or other materials provided with the distribution.
--
-- * Neither the name Mark Karpov nor the names of contributors may be used
--   to endorse or promote products derived from this software without
--   specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS “AS IS” AND ANY
-- EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
-- WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
-- OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
-- HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
-- STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
-- ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.

{-# LANGUAGE RecordWildCards #-}

module Codec.Audio.FLAC.StreamEncoderSpec
  ( spec )
where

import Codec.Audio.FLAC.StreamDecoder
import Codec.Audio.FLAC.StreamEncoder
import Codec.Audio.Wave
import Control.Monad
import Data.ByteString (ByteString)
import Data.Default.Class
import System.Directory
import System.FilePath
import System.IO
import System.IO.Temp (withSystemTempDirectory)
import Test.Hspec
import qualified Data.ByteString as B

-- NOTE OK, we test here a lot of things at the same time, which may
-- disappoint adepts of various testing techniques and principles, but it's
-- easier to test many things simultaneously in this case, and when
-- something is not right, it's usually obvious what's wrong.

spec :: Spec
spec =
  describe "encodeFlac and decodeFlac" $
    withVariousWaves $
      it "encodes and decodes back correctly" $ \path -> do
        -- Input and output paths coincide on purpose, we test that nothing
        -- bad can happen in this case.
        old <- Blind <$> fetchWaveBody path
        -- We first let the built-in verification mechanics catch possible
        -- errors.
        encodeFlac def { encoderVerify = True } path path
        -- Then we let decoder check that the streams match with MD5 hash.
        decodeFlac def { decoderMd5Checking = True } path path
        -- But we also want to be sure that audio streams match
        -- byte-by-byte, we can't trust just FLAC's own checking.
        new <- Blind <$> fetchWaveBody path
        new `shouldBe` old

----------------------------------------------------------------------------
-- Helpers

newtype Blind a = Blind a

instance Eq a => Eq (Blind a) where
  (Blind x) == (Blind y) = x == y

instance Show (Blind a) where
  show _ = "<blind data cannot be shown>"

-- | Run given test with various WAVE files.

withVariousWaves :: SpecWith FilePath -> SpecWith ()
withVariousWaves m =
  forM_ waveFiles $ \(path, desc) ->
    context ("when given " ++ desc) (around (withSandbox path) m)

-- | Make a temporary copy of given file and provide the path to the file in
-- a sandbox directory. Automatically remove the files when the test
-- finishes.

withSandbox :: FilePath -> ActionWith FilePath -> IO ()
withSandbox path action =
  withSystemTempDirectory "flac-test" $ \dir -> do
    let path' = dir </> "файл" -- testing Unicode
    copyFile path path'
    action path'

-- | Extract body of given WAVE or RF64 file as a strict 'ByteString'.
-- Needless to say that the body should be relatively short.

fetchWaveBody :: FilePath -> IO ByteString
fetchWaveBody path = do
  Wave {..} <- readWaveFile path
  withBinaryFile path ReadMode $ \h -> do
    hSeek h AbsoluteSeek (fromIntegral waveDataOffset)
    B.hGet h (fromIntegral waveDataSize)

waveFiles :: [(FilePath, String)]
waveFiles =
  [ ( "audio-samples/1ch-44100hz-16bit.rf64"
    , "1 channel 44100 Hz 16 bit (RF64)" )
  , ( "audio-samples/1ch-44100hz-16bit.wav"
    , "1 channel 44100 Hz 16 bit (WAVE)" )
  , ( "audio-samples/1ch-44100hz-16bit-x.wav"
    , "1 channel 44100 Hz 16 bit (WAVEX)" )
  , ( "audio-samples/2ch-11025hz-24bit.rf64"
    , "2 channels 11025 Hz 24 bit (RF64)" )
  , ( "audio-samples/2ch-11025hz-24bit.wav"
    , "2 channels 11025 Hz 24 bit (WAVE)" )
  , ( "audio-samples/2ch-11025hz-24bit-x.wav"
    , "2 channels 11025 Hz 24 bit (WAVEX)" )
  , ( "audio-samples/2ch-8000hz-8bit.rf64"
    , "2 channels 8000 Hz 8 bit (RF64)" )
  , ( "audio-samples/2ch-8000hz-8bit.wav"
    , "2 channels 8000 Hz 8 bit (WAVE)" )
  , ( "audio-samples/2ch-8000hz-8bit-x.wav"
    , "2 channels 8000 Hz 8 bit (WAVEX)" )
  , ( "audio-samples/1ch-44100hz-8bit-full-range.wav"
    , "1 channel 44100 Hz 8 bit full range (WAVE)" )
  , ( "audio-samples/1ch-44100hz-8bit-silence.wav"
    , "1 channel 44100 Hz 8 bit silence (WAVE)" )
  , ( "audio-samples/1ch-44100hz-16bit-full-range.wav"
    , "1 channel 44100 Hz 16 bit full range (WAVE)" )
  , ( "audio-samples/1ch-44100hz-16bit-silence.wav"
    , "1 channel 44100 Hz 16 bit silence (WAVE)" )
  , ( "audio-samples/1ch-44100hz-24bit-full-range.wav"
    , "1 channel 44100 Hz 24 bit full range (WAVE)" )
  , ( "audio-samples/1ch-44100hz-24bit-silence.wav"
    , "1 channel 44100 Hz 24 bit silence (WAVE)" )
  ]
