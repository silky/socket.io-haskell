--------------------------------------------------------------------------------
-- | String-like data structure utilities
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE FlexibleInstances #-}

module Web.SocketIO.Types.String (
        S.IsString(..)
    ,   IsByteString(..)
    ,   IsLazyByteString(..)
    ,   IsText(..)
    ,   IsLazyText(..)
    ,   Serializable(..)
    ,   Text
    ,   StrictText
    ,   ByteString
    ,   LazyByteString
    ,   (<>)
    ) where


--------------------------------------------------------------------------------
import qualified    Data.Aeson                              as Aeson
import qualified    Data.String                             as S
import qualified    Data.Text                               as T
import qualified    Data.Text.Encoding                      as TE
import qualified    Data.Text.Lazy                          as TL
import qualified    Data.Text.Lazy.Encoding                 as TLE
import              Data.ByteString                         (ByteString)
import qualified    Data.ByteString.Char8                   as BC
import qualified    Data.ByteString.Lazy                    as BL
import qualified    Data.ByteString.Lazy.Char8              as BLC
import              Data.Monoid                             ((<>), Monoid)

--------------------------------------------------------------------------------
-- | Lazy Text as default Text
type Text = TL.Text

--------------------------------------------------------------------------------
-- | Type synonym of Strict Text
type StrictText = T.Text

--------------------------------------------------------------------------------
-- | Type synonym of Lazy ByteString
type LazyByteString = BL.ByteString

--------------------------------------------------------------------------------
-- | Class for string-like data structures that can be converted from strict ByteString
class IsByteString a where
    fromByteString :: ByteString -> a

-- | to String
instance IsByteString String where
    fromByteString = BC.unpack

-- | to strict Text
instance IsByteString T.Text where
    fromByteString = TE.decodeUtf8

-- | to lazy Text
instance IsByteString TL.Text where
    fromByteString = TLE.decodeUtf8 . BL.fromStrict

-- | to strict ByteString (identity)
instance IsByteString ByteString where
    fromByteString = id

-- | to lazy ByteString
instance IsByteString BL.ByteString where
    fromByteString = BL.fromStrict

--------------------------------------------------------------------------------
-- | Class for string-like data structures that can be converted from lazy ByteString
class IsLazyByteString a where
    fromLazyByteString :: BL.ByteString -> a

-- | to String
instance IsLazyByteString String where
    fromLazyByteString = BLC.unpack

-- | to strict Text
instance IsLazyByteString T.Text where
    fromLazyByteString = TE.decodeUtf8 . BL.toStrict

-- | to lazy Text
instance IsLazyByteString TL.Text where
    fromLazyByteString = TLE.decodeUtf8

-- | to strict ByteString
instance IsLazyByteString ByteString where
    fromLazyByteString = BL.toStrict

-- | to lazy ByteString (identity)
instance IsLazyByteString BL.ByteString where
    fromLazyByteString = id

--------------------------------------------------------------------------------
-- | Class for string-like data structures that can be converted from strict Text
class IsText a where
    fromText :: T.Text -> a

-- | to String
instance IsText String where
    fromText = T.unpack

-- | to strict Text (identity)
instance IsText T.Text where
    fromText = id

-- | to lazy Text
instance IsText TL.Text where
    fromText = TL.fromStrict

-- | to strict ByteString
instance IsText ByteString where
    fromText = TE.encodeUtf8

-- | to lazy ByteString
instance IsText BL.ByteString where
    fromText = TLE.encodeUtf8 . TL.fromStrict

--------------------------------------------------------------------------------
-- | Class for string-like data structures that can be converted from lazy Text
class IsLazyText a where
    fromLazyText :: TL.Text -> a

-- | to String
instance IsLazyText String where
    fromLazyText = TL.unpack

-- | to strict Text
instance IsLazyText T.Text where
    fromLazyText = TL.toStrict

-- | to lazy Text (identity)
instance IsLazyText TL.Text where
    fromLazyText = id

-- | to strict ByteString
instance IsLazyText ByteString where
    fromLazyText = TE.encodeUtf8 . TL.toStrict

-- | to lazy ByteString
instance IsLazyText BL.ByteString where
    fromLazyText = TLE.encodeUtf8

--------------------------------------------------------------------------------
-- | Class for string-like data structures
class Serializable a where
    -- | converts instances to string-like data structures
    serialize :: ( Monoid s
                 , S.IsString s
                 , IsText s
                 , IsLazyText s
                 , IsByteString s
                 , IsLazyByteString s
                 , Show a) => a -> s
    serialize = S.fromString . show

instance Serializable Aeson.Value where
    serialize = fromLazyByteString . Aeson.encode

instance Serializable T.Text where
    serialize = fromText

instance Serializable TL.Text where
    serialize = fromLazyText

instance Serializable ByteString where
    serialize = fromByteString

instance Serializable BL.ByteString where
    serialize = fromLazyByteString

instance Serializable Bool
instance Serializable Char
instance Serializable Double
instance Serializable Float
instance Serializable Int
instance Serializable Integer
instance Serializable Ordering
instance Serializable ()
instance Serializable a => Serializable [a]
instance Serializable a => Serializable (Maybe a)
instance (Serializable a, Serializable b) => Serializable (Either a b)
instance (Serializable a, Serializable b, Serializable c) => Serializable (a, b, c)
instance (Serializable a, Serializable b, Serializable c, Serializable d) => Serializable (a, b, c, d)
instance (Serializable a, Serializable b, Serializable c, Serializable d, Serializable e) => Serializable (a, b, c, d, e)