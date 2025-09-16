extern fn indirect_from_c() i32;

pub fn indirect() i32 {
    return indirect_from_c();
}
