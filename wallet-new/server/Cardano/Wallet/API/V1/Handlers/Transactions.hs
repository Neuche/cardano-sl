{-# LANGUAGE ScopedTypeVariables #-}

module Cardano.Wallet.API.V1.Handlers.Transactions where

import           Universum

import qualified Pos.Wallet.Web.ClientTypes.Types as V0
import qualified Pos.Wallet.Web.Methods.History as V0
import qualified Pos.Wallet.Web.Methods.Payment as V0
import qualified Pos.Wallet.Web.Methods.Txp as V0

import           Cardano.Wallet.API.V1.Migration (MonadV1, HasConfigurations, HasCompileInfo, migrate)
import           Cardano.Wallet.API.Request
import           Cardano.Wallet.API.Response
import qualified Cardano.Wallet.API.V1.Transactions as Transactions
import           Cardano.Wallet.API.V1.Types

import           Servant
import           Test.QuickCheck (arbitrary, generate)
import qualified Data.List.NonEmpty as NE

handlers :: ( HasConfigurations
            , HasCompileInfo
            )
         => ServerT Transactions.API MonadV1

handlers = newTransaction
        :<|> allTransactions
        :<|> estimateFees

newTransaction
    :: forall ctx m . (V0.MonadWalletTxFull ctx m)
    => NewPayment -> m (WalletResponse Transaction)
newTransaction Payment {..} = do
    let spendingPw = fromMaybe mempty pmtSpendingPassword
    cAccountId <- migrate (pmtSourceWallet, pmtSourceAccount)
    addrCoinList <- migrate $ NE.toList pmtDestinations
  -- Set `OptimiseForSecurityPolicy` as default policy
    policy <- migrate $ fromMaybe OptimiseForSecurityPolicy pmtGroupingPolicy
    let batchPayment = V0.NewBatchPayment cAccountId addrCoinList policy
    cTx <- V0.newPaymentBatch spendingPw batchPayment
    single <$> migrate cTx

-- | The conclusion is that we want just the walletId for now, the details
-- in CSL-1917.
allTransactions
    :: forall ctx m. (V0.MonadWalletHistory ctx m)
    => WalletId
    -> RequestParams
    -> m (WalletResponse [Transaction])
allTransactions walletId requestParams = do
    cIdWallet    <- migrate walletId

    -- TODO(ks): We need the type signature, fix this?
    let transactions :: m [Transaction]
        transactions = V0.getHistory cIdWallet mempty Nothing >>= migrate

    respondWith requestParams (const transactions)

estimateFees :: Payment -> MonadV1 (WalletResponse EstimatedFees)
estimateFees _ = single <$> liftIO (generate arbitrary)
