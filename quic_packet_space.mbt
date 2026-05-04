///|
#cfg(target="native")
priv suberror QuicPacketSpaceError {
  QuicNoPacketToAck
} derive(Debug, ToJson)

///|
#cfg(target="native")
#warnings("-unused_constructor")
priv enum QuicPacketNumberSpaceKind {
  QuicInitialSpace
  QuicHandshakeSpace
  QuicApplicationSpace
}

///|
#cfg(target="native")
#warnings("-unused_field")
priv struct QuicPacketNumberSpaces {
  mut next_initial : Int
  mut next_handshake : Int
  mut next_application : Int
  mut largest_initial_received : Int
  mut largest_handshake_received : Int
  mut largest_application_received : Int
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn QuicPacketNumberSpaces::new() -> QuicPacketNumberSpaces {
  {
    next_initial: 0,
    next_handshake: 0,
    next_application: 0,
    largest_initial_received: -1,
    largest_handshake_received: -1,
    largest_application_received: -1,
  }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn QuicPacketNumberSpaces::next(
  self : QuicPacketNumberSpaces,
  space : QuicPacketNumberSpaceKind,
) -> Int {
  match space {
    QuicInitialSpace => {
      let n = self.next_initial
      self.next_initial += 1
      n
    }
    QuicHandshakeSpace => {
      let n = self.next_handshake
      self.next_handshake += 1
      n
    }
    QuicApplicationSpace => {
      let n = self.next_application
      self.next_application += 1
      n
    }
  }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn QuicPacketNumberSpaces::record_received(
  self : QuicPacketNumberSpaces,
  space : QuicPacketNumberSpaceKind,
  packet_number : Int,
) -> Unit {
  match space {
    QuicInitialSpace =>
      if packet_number > self.largest_initial_received {
        self.largest_initial_received = packet_number
      }
    QuicHandshakeSpace =>
      if packet_number > self.largest_handshake_received {
        self.largest_handshake_received = packet_number
      }
    QuicApplicationSpace =>
      if packet_number > self.largest_application_received {
        self.largest_application_received = packet_number
      }
  }
}

///|
#cfg(target="native")
fn QuicPacketNumberSpaces::largest_received(
  self : QuicPacketNumberSpaces,
  space : QuicPacketNumberSpaceKind,
) -> Int {
  match space {
    QuicInitialSpace => self.largest_initial_received
    QuicHandshakeSpace => self.largest_handshake_received
    QuicApplicationSpace => self.largest_application_received
  }
}

///|
#cfg(target="native")
#warnings("-unused_value")
fn QuicPacketNumberSpaces::ack_frame(
  self : QuicPacketNumberSpaces,
  space : QuicPacketNumberSpaceKind,
) -> Bytes raise {
  let largest = self.largest_received(space)
  guard largest >= 0 else { raise QuicNoPacketToAck }
  quic_encode_ack(largest, 0, 0)
}
