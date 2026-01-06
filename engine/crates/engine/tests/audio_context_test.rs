use engine::GameState;
use bytes::Buf;
use std::io::Cursor;

// Replicate OpCodes from lib.rs for testing
const OP_PLAY_SOUND: u8 = 0x07;

#[test]
fn test_audio_context_separation() {
    let script = r#"
        function update(dt)
            -- Should go to Global Event Buffer (Volume 1.0)
            api.play_sound("global_boom", false, 1.0)
        end

        function draw(session_id)
            -- Should go to Local Command Buffer (Volume 0.5)
            api.play_sound("local_pew", false, 0.5)
        end
    "#;

    let game = GameState::new(script).expect("Failed to init game");

    // 1. Run Update
    // This should write "global_boom" to event_buffer
    game.update(0.016).expect("Update failed");

    // 2. Run Draw
    // This should:
    // a) Append event_buffer ("global_boom") to output
    // b) Execute draw lua -> write "local_pew" to output
    let bytes = game.draw("sess_1").expect("Draw failed");

    // 3. Parse Bytes to verify
    let mut cursor = Cursor::new(bytes);
    
    // --- Verify First Sound (Global) ---
    assert_eq!(cursor.get_u8(), OP_PLAY_SOUND, "Expected OP_PLAY_SOUND (Global)");
    
    let len1 = cursor.get_u16_le() as usize;
    let pos1 = cursor.position() as usize;
    let name1 = String::from_utf8(cursor.get_ref()[pos1..pos1+len1].to_vec()).unwrap();
    cursor.advance(len1);
    assert_eq!(name1, "global_boom");
    
    let loop1 = cursor.get_u8();
    assert_eq!(loop1, 0);
    
    let vol1 = cursor.get_f32_le();
    assert_eq!(vol1, 1.0);

    // --- Verify Second Sound (Local) ---
    assert_eq!(cursor.get_u8(), OP_PLAY_SOUND, "Expected OP_PLAY_SOUND (Local)");
    
    let len2 = cursor.get_u16_le() as usize;
    let pos2 = cursor.position() as usize;
    let name2 = String::from_utf8(cursor.get_ref()[pos2..pos2+len2].to_vec()).unwrap();
    cursor.advance(len2);
    assert_eq!(name2, "local_pew");
    
    let loop2 = cursor.get_u8();
    assert_eq!(loop2, 0);
    
    let vol2 = cursor.get_f32_le();
    assert_eq!(vol2, 0.5);

    // Ensure no extra data
    assert!(!cursor.has_remaining(), "Buffer should be empty");
}

#[test]
fn test_draw_clears_local_buffer() {
    // Test ensuring local sounds don't leak to next frame
    let script = r#"
        function update(dt)
            -- No global sound
        end

        function draw(session_id)
            api.play_sound("local_only", false, 0.8)
        end
    "#;

    let game = GameState::new(script).expect("Failed to init");

    // Frame 1
    game.update(0.16).unwrap();
    let bytes1 = game.draw("s1").unwrap();
    assert!(bytes1.len() > 0); // Contains local_only

    // Frame 2 - Reset
    game.begin_frame(); // Clears global event buffer
    game.update(0.16).unwrap(); 
    
    // But what if we DON'T call draw? The command buffer is technically persistent in the struct until cleared inside draw.
    // Let's verify draw() clears it properly.
    
    let bytes2 = game.draw("s1").unwrap();
    // Should contain "local_only" again (generated in THIS draw call), but NOT two copies.
    
    let mut cursor = Cursor::new(bytes2);
    // Count occurrences of OP_PLAY_SOUND
    let mut count = 0;
    while cursor.has_remaining() {
        if cursor.get_u8() == OP_PLAY_SOUND {
            count += 1;
            let len = cursor.get_u16_le() as usize;
            cursor.advance(len); // Name
            cursor.advance(1); // Loop
            cursor.advance(4); // Volume
        }
    }
    assert_eq!(count, 1, "Should only have 1 sound per frame");
}
