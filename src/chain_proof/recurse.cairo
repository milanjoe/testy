from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.hash import HashBuiltin
from starkware.cairo.common.memcpy import memcpy

from block.compute_median import TIMESTAMP_COUNT
from block.block import State, ChainState
from crypto.hash_utils import HASH_FELT_SIZE
from utxo_set.utreexo import UTREEXO_ROOTS_LEN
from crypto.hash_utils import assert_hashes_equal

from stark_verifier.stark_verifier import read_and_verify_stark_proof

func recurse{pedersen_ptr: HashBuiltin*, range_check_ptr, bitwise_ptr: BitwiseBuiltin*}(
    block_height, expected_program_hash, prev_state: State) {
    alloc_locals;

    // For the genesis block there is no parent proof to verify
    if(block_height == 0){
        return ();
    }

    // 1. Read the public inputs of the parent proof from a hint
    // and compute the program's hash
    %{
        from src.stark_verifier.utils import set_proof_path, debug_print
        set_proof_path(f'tmp/chain_proof-{ids.prev_state.chain_state.block_height}.bin')
    %}
    let (program_hash, mem_values) = read_and_verify_stark_proof();

    // 2. Compare the `program_hash` to the `expected_program_hash` 
    // given to us as a public input to the child proof. This is to resolve the hash cycle,
    // because a program cannot contain its own hash.
    assert expected_program_hash = program_hash;

    // 3. Parse the `next_state` of the parent proof from its public inputs
    // and then verify it is equal to the child proof's `prev_state`
    verify_prev_state(mem_values, prev_state, program_hash);
    return ();
}

func verify_prev_state(mem_values: felt*, prev_state: State, program_hash){
    let chain_state = prev_state.chain_state;
    
    assert chain_state.block_height = mem_values[0];
    let mem_values = mem_values + 1;

    assert_hashes_equal(chain_state.best_block_hash, mem_values);
    let mem_values = mem_values + HASH_FELT_SIZE;


    assert chain_state.total_work = mem_values[0];
    assert chain_state.current_target = mem_values[1];
    let mem_values = mem_values + 2;
    
    memcpy(chain_state.prev_timestamps, mem_values, TIMESTAMP_COUNT);
    let mem_values = mem_values + TIMESTAMP_COUNT;
    
    assert chain_state.epoch_start_time = mem_values[0];
    let mem_values = mem_values + 1;

    memcpy(prev_state.utreexo_roots, mem_values, UTREEXO_ROOTS_LEN);
    let mem_values = mem_values + UTREEXO_ROOTS_LEN;



    assert program_hash = mem_values[0];

    return ();
}

