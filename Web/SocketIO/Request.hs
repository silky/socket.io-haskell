--------------------------------------------------------------------------------
-- | Converts HTTP requests to Socket.IO requests and run them
{-# LANGUAGE OverloadedStrings #-}

module Web.SocketIO.Request (runRequest) where

--------------------------------------------------------------------------------
import              Web.SocketIO.Types
import              Web.SocketIO.Protocol

--------------------------------------------------------------------------------
import              Blaze.ByteString.Builder        (Builder)
import qualified    Blaze.ByteString.Builder        as Builder
import qualified    Data.ByteString                 as B
import              Data.Conduit
import qualified    Data.Conduit.List               as CL
import qualified    Network.Wai                     as Wai

--------------------------------------------------------------------------------
-- | Run!
runRequest :: Wai.Request -> (Request -> IO Message) -> Source IO (Flush Builder)
runRequest request runner = sourceRequest request $= CL.mapM runner =$= serializeMessage =$= toFlushBuilder

--------------------------------------------------------------------------------
-- | Extracts and identifies Requests from Wai.Request
sourceRequest :: Wai.Request -> Source IO Request
sourceRequest request = do
    let path = parsePath (Wai.rawPathInfo request)
    let method = Wai.requestMethod request

    case (method, path) of
        ("GET", (WithoutSession _ _)) -> yield Handshake
        ("GET", (WithSession _ _ _ sessionID)) -> yield (Connect sessionID)
        ("POST", (WithSession _ _ _ sessionID)) -> do
            Wai.requestBody request $= parseMessage =$= filterMsgEvent sessionID
        (_, (WithSession _ _ _ sessionID)) -> yield (Disconnect sessionID)
        _ -> error "error handling http request"
    where   filterMsgEvent sessionID = do
                message <- await
                case message of
                    Just (MsgEvent _ _ event) -> yield (Emit sessionID event)
                    _ -> return ()

--------------------------------------------------------------------------------
-- | Serialize Messages, frame when necessary.
serializeMessage :: Conduit Message IO ByteString
serializeMessage = toByteString 0
    where   toByteString :: Int -> Conduit Message IO ByteString
            toByteString i = do
                m <- await
                n <- await
                case (m, n) of
                    -- []
                    (Nothing, Nothing) -> yield (serialize (Framed [] :: Framed Message))
                    -- [m'], singleton
                    (Just m', Nothing) -> if i == 0
                        then yield (serialize m') -- true singleton
                        else yield (frame m') -- just a recursion base case 
                    -- WTF
                    (Nothing, Just _ ) -> return ()
                    -- [m', n'], frame m', leftover n'
                    (Just m', Just n') -> do
                        yield (frame m')
                        leftover n'
                        toByteString (i + 1)
                        
            frame b = "�" <> serialize size <> "�" <> b'
                where   b' = serialize b
                        size = B.length b'

--------------------------------------------------------------------------------
-- | Convert Framed Message to Flush Builder so that `Wai.responseSource` can consume it
toFlushBuilder :: Conduit ByteString IO (Flush Builder)
toFlushBuilder = do 
    b <- await
    case b of
        Just b' -> yield $ Chunk (Builder.fromByteString b')
        Nothing -> yield $ Flush