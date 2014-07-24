import Data.Maybe
import Data.Word
import Data.Scientific
import Data.Binary
import System.Environment
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as B8
import qualified Data.ByteString.Builder as BSB

import Network.Haskoin.Crypto
import Network.Haskoin.Util

interactLines :: (String -> String) -> IO ()
interactLines f = interact (unlines . map f . lines)

interactWords :: (String -> String) -> IO ()
interactWords f = interactLines (unwords . map f . words)

one_btc_in_satoshi :: Num a => a
one_btc_in_satoshi = 10^(8 :: Int)

hx_pubkey, hx_addr, hx_wif_to_secret, hx_secret_to_wif,
  hx_hd_to_wif, hx_hd_to_address, hx_hex_to_mnemonic,
  hx_mnemonic_to_hex, hx_btc, hx_satoshi,
  hx_base58_encode, hx_base58_decode, hx_base58check_encode, hx_base58check_decode,
  hx_decode_addr
  :: String -> String

hx_pubkey = bsToHex . encode' . derivePubKey
          . fromMaybe (error "invalid WIF private key") . fromWIF

hx_addr = addrToBase58 . pubKeyAddr . decode'
        . fromMaybe (error "invalid hex encoding") . hexToBS

hx_wif_to_secret = bsToHex . runPut' . putPrvKey
                 . fromMaybe (error "invalid WIF private key") . fromWIF

hx_secret_to_wif = toWIF
                 . fromMaybe (error "invalid private key") . makePrvKey
                 . bsToInteger
                 . fromMaybe (error "invalid hex encoding") . hexToBS

hx_hd_to_wif = xPrvWIF
             . fromMaybe (error "invalid extended private key") . xPrvImport

-- TODO support private keys as well
hx_hd_to_address
  = addrToBase58 . xPubAddr
  . fromMaybe (error "invalid extended public key") . xPubImport

hx_hd_priv :: (XPrvKey -> Word32 -> Maybe XPrvKey) -> Word32 -> String -> String
hx_hd_priv sub i = xPrvExport
                 . fromMaybe (error "failed to derive private sub key") . flip sub i
                 . fromMaybe (error "invalid extended private key") . xPrvImport

hx_hd_pub :: Maybe Word32 -> String -> String
hx_hd_pub Nothing
  = xPubExport
  . deriveXPubKey
  . fromMaybe (error "invalid extended private key") . xPrvImport
hx_hd_pub (Just i)
  = xPubExport
  . fromMaybe (error "failed to derive public sub key") . flip pubSubKey i
  . fromMaybe (error "invalid extended public key") . xPubImport

hx_hex_to_mnemonic = either error id . toMnemonic
                   . fromMaybe (error "invalid hex encoding") . hexToBS

hx_mnemonic_to_hex = bsToHex . either error id . fromMnemonic

hx_btc     = formatScientific Fixed (Just 8) . (/ one_btc_in_satoshi) . read
hx_satoshi = formatScientific Fixed (Just 0) . (* one_btc_in_satoshi) . read

hx_decode_addr = bsToHex . encode' . getAddrHash
               . fromMaybe (error "invalid bitcoin address") . base58ToAddr

hx_encode_addr :: (Word160 -> Address) -> String -> String
hx_encode_addr f = addrToBase58 . f
                 . runGet' get
                 . fromMaybe (error "invalid hex encoding") . hexToBS

hx_base58_encode = B8.unpack . encodeBase58
                 . fromMaybe (error "invalid hex encoding") . hexToBS

hx_base58_decode = bsToHex . fromMaybe (error "invalid base58 encoding") . decodeBase58 . B8.pack

hx_base58check_encode = B8.unpack . encodeBase58Check
                      . fromMaybe (error "invalid hex encoding") . hexToBS

hx_base58check_decode = bsToHex
                      . fromMaybe (error "invalid base58check encoding")
                      . decodeBase58Check . B8.pack

-- TODO do something better than 'read' to parse the index
parseWord32 :: String -> Word32
parseWord32 = read

-- | Encode a bytestring to a base16 (HEX) representation
bsToHex' :: BS.ByteString -> BS.ByteString
bsToHex' = toStrictBS . BSB.toLazyByteString . BSB.byteStringHex

mainArgs :: [String] -> IO ()
mainArgs ["pubkey"]                  = interactWords hx_pubkey
mainArgs ["addr"]                    = interactWords hx_addr
mainArgs ["wif-to-secret"]           = interactWords hx_wif_to_secret
mainArgs ["secret-to-wif"]           = interactWords hx_secret_to_wif
mainArgs ["hd-priv", i]              = interactWords . hx_hd_priv prvSubKey   $ parseWord32 i
mainArgs ["hd-priv", "--hard", i]    = interactWords . hx_hd_priv primeSubKey $ parseWord32 i
mainArgs ["hd-pub"]                  = interactWords . hx_hd_pub              $ Nothing
mainArgs ["hd-pub", i]               = interactWords . hx_hd_pub              $ Just (parseWord32 i)
mainArgs ["hd-to-wif"]               = interactWords hx_hd_to_wif
mainArgs ["hd-to-address"]           = interactWords hx_hd_to_address
mainArgs ["hex-to-mnemonic"]         = interactWords hx_hex_to_mnemonic
mainArgs ["mnemonic-to-hex"]         = interactWords hx_mnemonic_to_hex
mainArgs ["base58-encode"]           = interactWords hx_base58_encode
mainArgs ["base58-decode"]           = interactWords hx_base58_decode
mainArgs ["base58check-encode"]      = interactWords hx_base58check_encode
mainArgs ["base58check-decode"]      = interactWords hx_base58check_decode
mainArgs ["encode-addr", "--script"] = interactWords $ hx_encode_addr ScriptAddress
mainArgs ["encode-addr"]             = interactWords $ hx_encode_addr PubKeyAddress
mainArgs ["decode-addr"]             = interactWords hx_decode_addr
mainArgs ["ripemd-hash"]             = BS.interact $ bsToHex' . hash160BS
mainArgs ["sha256"]                  = BS.interact $ bsToHex' . hash256BS
mainArgs ["btc", x]                  = putStrLn $ hx_btc x
mainArgs ["satoshi", x]              = putStrLn $ hx_satoshi x
mainArgs _ = error $ unlines ["Unexpected arguments."
                             ,""
                             ,"Supported commands:"
                             ,"hx pubkey"
                             ,"hx addr"
                             ,"hx wif-to-secret"
                             ,"hx secret-to-wif"
                             ,"hx hd-priv INDEX"
                             ,"hx hd-priv --hard INDEX"
                             ,"hx hd-pub"
                             ,"hx hd-pub INDEX"
                             ,"hx hd-to-wif"
                             ,"hx hd-to-address"
                             ,"hx base58-encode"
                             ,"hx base58-decode"
                             ,"hx base58check-encode"
                             ,"hx base58check-decode"
                             ,"hx encode-addr"
                             ,"hx encode-addr --script"
                             ,"hx decode-addr"
                             ,"[1] hx ripemd-hash"
                             ,"[1] hx sha256"
                             ,"[2] hx hex-to-mnemonic"
                             ,"[2] hx mnemonic-to-hex"
                             ,""
                             ,"[1]: The output is consistent with openssl but NOT with sx"
                             ,"[2]: The output is NOT consistent with sx (nor electrum I guess)"
                             ]

main :: IO ()
main = getArgs >>= mainArgs
