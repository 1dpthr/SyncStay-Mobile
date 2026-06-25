class Room {
  String roomId;
  String block;
  int floor;
  String roomNumber;
  int capacity;
  int currentOccupancy;
  String roomType; // e.g., "standard", "deluxe", "suite"
  bool hasAttachedBathroom;
  bool hasAC;
  bool hasWifi;
  bool isFurnished;
  bool hasKitchenAccess;
  bool hasLaundry;
  String sharingType; // "Single", "Double"
  String location;
  double basePrice;
  List<String> occupantsIds; // List of student IDs currently in the room
  List<String> imageUrls;

  Room({
    required this.roomId,
    required this.block,
    required this.floor,
    required this.roomNumber,
    required this.capacity,
    this.currentOccupancy = 0,
    this.roomType = 'standard',
    this.hasAttachedBathroom = false,
    this.hasAC = false,
    this.hasWifi = false,
    this.isFurnished = false,
    this.hasKitchenAccess = false,
    this.hasLaundry = false,
    this.sharingType = 'Double',
    this.location = 'Main Campus',
    this.basePrice = 10000.0,
    List<String>? occupantsIds,
    List<String>? imageUrls,
  }) : occupantsIds = occupantsIds ?? [], imageUrls = imageUrls ?? [];

  double calculateTotalPrice() {
    double total = basePrice;
    if (hasAC) total += 5000;
    if (hasAttachedBathroom) total += 3000;
    if (isFurnished) total += 2000;
    if (hasWifi) total += 1000;
    if (sharingType == 'Single') total += 5000;
    return total;
  }

  bool isFull() {
    return currentOccupancy >= capacity;
  }

  bool addOccupant(String studentId) {
    if (!isFull()) {
      occupantsIds.add(studentId);
      currentOccupancy++;
      return true;
    }
    return false;
  }

  bool removeOccupant(String studentId) {
    if (occupantsIds.contains(studentId)) {
      occupantsIds.remove(studentId);
      currentOccupancy--;
      return true;
    }
    return false;
  }

  String get availabilityStatus => isFull() ? 'Full' : 'Available';

  @override
  String toString() {
    return 'Room $roomId ($location, $block-$roomNumber) - Price: ${calculateTotalPrice()}';
  }
}
