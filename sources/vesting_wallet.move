// this module is for educational purpose
// cannot be used in production
module sui_playground::vesting_wallet {

    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::tx_context::TxContext;
    use sui::clock::{Self, Clock};
    use sui::transfer;

    const EDurationCannotBeZero: u64 = 0;
    const ENotEnoughToRelease: u64 = 1;

    struct VestingWallet<phantom T> has key, store {
        id: UID,
        balance: Balance<T>,
        // settings
        start: u64,
        duration: u64,
        // record
        released_amount: u64,
    }

    public fun new<T>(
        input: Balance<T>,
        start: u64,
        duration: u64,
        ctx: &mut TxContext,
    ): VestingWallet<T> {
        assert!(duration > 0, EDurationCannotBeZero);
        VestingWallet {
            id: object::new(ctx),
            balance: input,
            start,
            duration,
            released_amount: 0,
        }
    }

    public entry fun create<T>(
        input: Coin<T>,
        start: u64,
        duration: u64,
        to: address,
        ctx: &mut TxContext,
    ) {
        let input_balance = coin::into_balance(input);
        let vesting_wallet = new(input_balance, start, duration, ctx);
        transfer::transfer(vesting_wallet, to);
    }

    public fun release<T>(
        clock: &Clock,
        vesting_wallet: &mut VestingWallet<T>,
    ): Balance<T> {
        let vested_amount = vested_amount(clock, vesting_wallet);
        assert!(vested_amount > vesting_wallet.released_amount, ENotEnoughToRelease);
        let releasable_amount = vested_amount - vesting_wallet.released_amount;
        vesting_wallet.released_amount = vesting_wallet.released_amount + releasable_amount;
        balance::split(&mut vesting_wallet.balance, releasable_amount)
    }

    public entry fun release_to<T>(
        clock: &Clock,
        vesting_wallet: &mut VestingWallet<T>,
        to: address,
        ctx: &mut TxContext,
    ) {
        let output_balance = release(clock, vesting_wallet);
        let output_coin = coin::from_balance(output_balance, ctx);
        transfer::public_transfer(output_coin, to);
    }

    public fun vested_amount<T>(clock: &Clock, vesting_wallet: &VestingWallet<T>): u64 {
        let current_time = clock::timestamp_ms(clock);
        let initial_balance = initial_balance(vesting_wallet);
        if (current_time <= vesting_wallet.start) {
            0
        } else if (current_time >= vesting_wallet.start + vesting_wallet.duration) {
            initial_balance
        } else {
            initial_balance * (current_time - vesting_wallet.start) / vesting_wallet.duration
        }
    }

    public fun start<T>(vesting_wallet: &VestingWallet<T>): u64 {
        vesting_wallet.start
    }

    public fun duration<T>(vesting_wallet: &VestingWallet<T>): u64 {
        vesting_wallet.duration
    }

    public fun released_amount<T>(vesting_wallet: &VestingWallet<T>): u64 {
        vesting_wallet.released_amount
    }

    public fun current_balance<T>(vesting_wallet: &VestingWallet<T>): u64 {
        balance::value(&vesting_wallet.balance)
    }

    public fun initial_balance<T>(vesting_wallet: &VestingWallet<T>): u64 {
        current_balance(vesting_wallet) + vesting_wallet.released_amount
    }

    public entry fun destroy_empty<T>(vesting_wallet: VestingWallet<T>) {
        let VestingWallet {id, balance, start: _, duration: _, released_amount: _} = vesting_wallet;
        object::delete(id);
        balance::destroy_zero(balance);
    }
}