namespace ewm;

entity GoodsReceipts {
  key ID        : UUID;
      material  : String(40);
      warehouse : String(20);
      quantity  : Integer;
      unit      : String(3);
      status    : String(20);
      receivedAt: Timestamp;
}
