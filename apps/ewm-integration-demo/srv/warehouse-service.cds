using { ewm.GoodsReceipts as dbGoodsReceipts } from '../db/schema';

@path: 'warehouse'
service WarehouseService {
  @readonly
  entity GoodsReceipts as projection on dbGoodsReceipts;
}
