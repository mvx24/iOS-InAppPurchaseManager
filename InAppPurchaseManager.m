//
//  InAppPurchaseManager.m
//
//  Copyright (c) 2012 Symbiotic Software LLC. All rights reserved.
//

#import "InAppPurchaseManager.h"

static id sharedInstance = nil;

@interface InAppPurchaseManager ()
{
	BOOL started;
}
- (void)applicationWillTerminate:(NSNotification *)notification;
@end

@implementation InAppPurchaseManager

#pragma mark - Internal methods

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self release];
}

#pragma mark - Methods

+ (InAppPurchaseManager *)sharedManager
{
	if(sharedInstance == nil)
	{
		sharedInstance = [[InAppPurchaseManager alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:sharedInstance selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];
	}
	return (InAppPurchaseManager *)sharedInstance;
}

- (void)startManager
{
	if(!started)
	{
		[[SKPaymentQueue defaultQueue] addTransactionObserver:sharedInstance];
		started = YES;
	}
}

- (BOOL)canMakePurchases
{
    return [SKPaymentQueue canMakePayments];
}

- (void)restoreCompletedTransactions
{
	[self startManager];
	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)purchase:(NSString *)productId
{
	SKPayment *payment;
	[self startManager];
	payment = [SKPayment paymentWithProductIdentifier:productId];
	[[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (void)finishTransaction:(SKPaymentTransaction *)transaction
{
	[[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

#pragma mark - SKPaymentTransactionObserver methods

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
	NSDictionary *userInfo;
	NSString *notification;
	BOOL success;
	
	for(SKPaymentTransaction *transaction in transactions)
	{
		success = NO;
		notification = nil;
		switch(transaction.transactionState)
		{
			case SKPaymentTransactionStatePurchased:
				userInfo = [NSDictionary dictionaryWithObjectsAndKeys:transaction, KEY_TRANSACTION, [[transaction payment] productIdentifier], KEY_PRODUCT_ID, nil];
				notification = NOTIFICATION_PURCHASE_SUCCEEDED;
				success = YES;
				break;
			case SKPaymentTransactionStateFailed:
				if(transaction.error.code != SKErrorPaymentCancelled)
				{
					userInfo = [NSDictionary dictionaryWithObjectsAndKeys:transaction, KEY_TRANSACTION, [[transaction payment] productIdentifier], KEY_PRODUCT_ID, transaction.error, KEY_TRANSACTION_ERROR, nil];
					notification = NOTIFICATION_PURCHASE_FAILED;
				}
				else
				{
					userInfo = [NSDictionary dictionaryWithObjectsAndKeys:transaction, KEY_TRANSACTION, [[transaction payment] productIdentifier], KEY_PRODUCT_ID, nil];
					notification = NOTIFICATION_PURCHASE_FAILED;
				}
				break;
			case SKPaymentTransactionStateRestored:
				userInfo = [NSDictionary dictionaryWithObjectsAndKeys:transaction, KEY_TRANSACTION, [[transaction.originalTransaction payment] productIdentifier], KEY_PRODUCT_ID, nil];
				notification = NOTIFICATION_PURCHASE_SUCCEEDED;
				success = YES;
				break;
			default:
				break;
		}
		
		if(notification)
		{
			if(success)
			{
				NSString *productId = [userInfo objectForKey:KEY_PRODUCT_ID];
				[[NSUserDefaults standardUserDefaults] setValue:transaction.transactionReceipt forKey:[NSString stringWithFormat:@"%@Receipt", productId]];
				[[NSUserDefaults standardUserDefaults] setBool:YES forKey:productId];
				[[NSUserDefaults standardUserDefaults] synchronize];
			}
			else
			{
				// Failure, go ahead and finish the transaction
				[[SKPaymentQueue defaultQueue] finishTransaction:transaction];
			}
			[[NSNotificationCenter defaultCenter] postNotificationName:notification object:self userInfo:userInfo];
		}
	}
}

@end
