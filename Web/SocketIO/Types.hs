{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}

module Web.SocketIO.Types
    (   module Web.SocketIO.Types.Log
    ,   module Web.SocketIO.Types.Request
    ,   module Web.SocketIO.Types.SocketIO
    ,   module Web.SocketIO.Types.String
    ,   ConnectionM(..)
    ,   SessionM(..)
    ,   ConnectionLayer(..)
    ,   SessionLayer(..)
    ,   Env(..)
    ,   Session(..)
    ,   SessionState(..)
    ,   Status(..)
    ,   Table
    ) where

--------------------------------------------------------------------------------
import              Web.SocketIO.Types.Request
import              Web.SocketIO.Types.Log
import              Web.SocketIO.Types.String
import              Web.SocketIO.Types.SocketIO

--------------------------------------------------------------------------------
import              Control.Applicative
import              Control.Concurrent.MVar.Lifted
import              Control.Concurrent.Chan.Lifted
import              Control.Monad.Reader       
import              Control.Monad.Trans.Control
import              Control.Monad.Base

import qualified    Data.HashMap.Strict                     as H
import              Data.IORef.Lifted

--------------------------------------------------------------------------------
type Table = H.HashMap SessionID Session 
data Status = Connecting | Connected | Disconnecting deriving Show

--------------------------------------------------------------------------------
data SessionState   = SessionSyn
                    | SessionAck
                    | SessionPolling
                    | SessionEmit Emitter
                    | SessionDisconnect
                    | SessionError

--------------------------------------------------------------------------------
data Env = Env { 
    sessionTable :: IORef Table, 
    handler :: HandlerM (), 
    configuration :: Configuration,
    stdout :: Chan String,
    globalBuffer :: Buffer
}

--------------------------------------------------------------------------------
class ConnectionLayer m where
    getEnv :: m Env
    getSessionTable :: m (IORef Table)
    getHandler :: m (HandlerM ())
    getConfiguration :: m Configuration

--------------------------------------------------------------------------------
class SessionLayer m where
    getSession :: m Session
    getSessionID :: m SessionID
    getStatus :: m Status
    getBufferHub :: m BufferHub
    getLocalBuffer :: m Buffer
    getGlobalBuffer :: m Buffer
    getListener :: m [Listener]
    getTimeoutVar :: m (MVar ())

--------------------------------------------------------------------------------
newtype ConnectionM a = ConnectionM { runConnectionM :: ReaderT Env IO a }
    deriving (Monad, Functor, Applicative, MonadIO, MonadReader Env, MonadBase IO)

--------------------------------------------------------------------------------
instance ConnectionLayer ConnectionM where
    getEnv = ask
    getSessionTable = sessionTable <$> ask
    getHandler = handler <$> ask
    getConfiguration = configuration <$> ask

--------------------------------------------------------------------------------
instance (MonadBaseControl IO) ConnectionM where
    newtype StM ConnectionM a = StMConnection { unStMConnection :: StM (ReaderT Env IO) a }
    liftBaseWith f = ConnectionM (liftBaseWith (\run -> f (liftM StMConnection . run . runConnectionM)))
    restoreM = ConnectionM . restoreM . unStMConnection

--------------------------------------------------------------------------------
data Session = Session { 
    sessionID :: SessionID, 
    status :: Status, 
    bufferHub :: BufferHub, 
    listener :: [Listener],
    timeoutVar :: MVar ()
} | NoSession

--------------------------------------------------------------------------------
newtype SessionM a = SessionM { runSessionM :: (ReaderT Session ConnectionM) a }
    deriving (Monad, Functor, Applicative, MonadIO, MonadReader Session, MonadBase IO)

--------------------------------------------------------------------------------
instance ConnectionLayer SessionM where
    getEnv = SessionM (lift ask)
    getSessionTable = sessionTable <$> getEnv
    getHandler = handler <$> getEnv
    getConfiguration = configuration <$> getEnv

--------------------------------------------------------------------------------
instance SessionLayer SessionM where
    getSession = ask
    getSessionID = sessionID <$> ask
    getStatus = status <$> ask
    getBufferHub = bufferHub <$> ask
    getLocalBuffer = selectLocalBuffer . bufferHub <$> ask
    getGlobalBuffer = selectGlobalBuffer . bufferHub <$> ask
    getListener = listener <$> ask
    getTimeoutVar = timeoutVar <$> ask

--------------------------------------------------------------------------------
instance (MonadBaseControl IO) SessionM where
    newtype StM SessionM a = StMSession { unStMSession :: StM (ReaderT Session ConnectionM) a }
    liftBaseWith f = SessionM (liftBaseWith (\run -> f (liftM StMSession . run . runSessionM)))
    restoreM = SessionM . restoreM . unStMSession