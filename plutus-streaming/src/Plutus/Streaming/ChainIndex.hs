module Plutus.Streaming.ChainIndex (
  utxoState,
  utxoState',
  UtxoState,
  TxUtxoBalance
) where

import Plutus.ChainIndex (TxUtxoBalance)
import Plutus.ChainIndex.Compatibility qualified as CI
import Plutus.ChainIndex.TxUtxoBalance qualified as TxUtxoBalance
import Plutus.ChainIndex.UtxoState (UtxoIndex, UtxoState)
import Plutus.ChainIndex.UtxoState qualified as UtxoState
import Plutus.Streaming
import Streaming
import Streaming.Prelude qualified as S

utxoState ::
  Monad m =>
  Stream (Of SimpleChainSyncEvent) m r ->
  Stream (Of (UtxoState TxUtxoBalance)) m r
utxoState =
  S.map snd . utxoState'

utxoState' ::
  Monad m =>
  Stream (Of SimpleChainSyncEvent) m r ->
  Stream (Of (SimpleChainSyncEvent, UtxoState TxUtxoBalance)) m r
utxoState' =
  S.scanned step initial projection
  where
    step index (RollForward block _) =
      case CI.fromCardanoBlock block of
        Left err -> error ("FromCardanoError: " <> show err)
        Right txs ->
          let tip = CI.tipFromCardanoBlock block
              balance = TxUtxoBalance.fromBlock tip txs
           in case UtxoState.insert balance index of
                Left err ->
                  error (show err)
                Right (UtxoState.InsertUtxoSuccess newIndex _insertPosition) ->
                  newIndex
    step index (RollBackward cardanoPoint _) =
      let point = CI.fromCardanoPoint cardanoPoint
       in case TxUtxoBalance.rollback point index of
            Left err -> error (show err)
            Right (UtxoState.RollbackResult _newTip rolledBackIndex) ->
              rolledBackIndex

    initial :: UtxoIndex TxUtxoBalance
    initial = mempty

    projection = UtxoState.utxoState
