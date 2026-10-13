import WalkData

/// Display mapping of docs/data/equipment-schema.md; unknown values stay unselected.
enum EquipmentClassificationOptions {
    static let categories = CatalogEquipmentCategory.allCases

    static func types(for category: CatalogEquipmentCategory?) -> [CatalogEquipmentType] {
        guard let category else { return [] }
        switch category {
        case .backpack:
            return [.backpack, .backpackRainCover]
        case .tent:
            return [.tent, .groundsheet, .tentPeg]
        case .sleeping:
            return [.sleepingBag, .sleepingPad, .sleepingQuilt, .pillow, .sleepingBagLiner]
        case .clothing:
            return [.clothing, .socks, .hat, .gloves, .sunglasses, .storageBag]
        case .hikingFootwear:
            return [.hikingShoes]
        case .walkingAids:
            return [.trekkingPole, .crampon, .tractionChain, .snowshoe, .riverCrossingShoes]
        case .campEssentials:
            return [.campShoes, .campChair, .campTable, .sitPad, .tarp]
        case .diningEquipment:
            return [.stove, .cookware, .tableware, .waterBottle, .hydrationReservoir, .waterFilter, .storageBag]
        case .navigationCommunication:
            return [.map, .compass, .gpsDevice, .twoWayRadio, .satelliteCommunicator]
        case .lightingPower:
            return [.headlamp, .flashlight, .campLight, .powerBank, .battery, .chargingCable]
        case .safetyEmergency:
            return [.firstAidKit, .whistle, .emergencyBlanket, .knife, .repairTool, .repairMaterial]
        case .hygieneCare:
            return [.toothbrush, .towel, .toiletPaper, .trowel, .sunscreen, .insectRepellent, .menstrualProduct]
        case .miscellaneous:
            return [.waistPack, .key, .document]
        case .food:
            return [.food]
        case .drinkingWater:
            return [.drinkingWater]
        case .fuel:
            return [.fuel]
        }
    }

    static func label(for category: CatalogEquipmentCategory) -> String {
        switch category {
        case .backpack: "背包"
        case .tent: "帐篷"
        case .sleeping: "睡眠系统"
        case .clothing: "衣服"
        case .hikingFootwear: "徒步鞋"
        case .walkingAids: "行进辅助"
        case .campEssentials: "营地用品"
        case .diningEquipment: "饮食装备"
        case .navigationCommunication: "导航通信"
        case .lightingPower: "照明供电"
        case .safetyEmergency: "安全应急"
        case .hygieneCare: "卫生护理"
        case .miscellaneous: "杂项"
        case .food: "食品"
        case .drinkingWater: "饮水"
        case .fuel: "燃料"
        }
    }

    static func label(for type: CatalogEquipmentType) -> String {
        switch type {
        case .backpack: "背包"
        case .tent: "帐篷"
        case .sleepingBag: "睡袋"
        case .sleepingPad: "睡垫"
        case .backpackRainCover: "背包防雨罩"
        case .groundsheet: "地布"
        case .tentPeg: "地钉"
        case .sleepingQuilt: "睡眠被"
        case .pillow: "枕头"
        case .sleepingBagLiner: "睡袋内胆"
        case .clothing: "衣裤、雨衣"
        case .socks: "袜子"
        case .hat: "帽子"
        case .gloves: "手套"
        case .sunglasses: "太阳镜"
        case .hikingShoes: "徒步鞋"
        case .trekkingPole: "登山杖"
        case .crampon: "冰爪、简易冰爪"
        case .tractionChain: "防滑链"
        case .snowshoe: "雪鞋"
        case .riverCrossingShoes: "另带的溯溪鞋"
        case .campShoes: "营地鞋、拖鞋"
        case .campChair: "营地椅"
        case .campTable: "营地桌"
        case .sitPad: "坐垫"
        case .tarp: "独立天幕"
        case .stove: "炉具"
        case .cookware: "锅具"
        case .tableware: "餐具"
        case .waterBottle: "水瓶"
        case .hydrationReservoir: "水袋"
        case .waterFilter: "滤水器"
        case .storageBag: "独立收纳袋、压缩袋、防水袋、食品储存袋"
        case .map: "地图"
        case .compass: "指南针"
        case .gpsDevice: "GPS 设备"
        case .twoWayRadio: "对讲机"
        case .satelliteCommunicator: "卫星通信器"
        case .headlamp: "头灯"
        case .flashlight: "手电"
        case .campLight: "营地灯"
        case .powerBank: "充电宝"
        case .battery: "电池"
        case .chargingCable: "充电线"
        case .firstAidKit: "急救包"
        case .whistle: "救生哨"
        case .emergencyBlanket: "应急毯"
        case .knife: "刀具"
        case .repairTool: "维修工具"
        case .repairMaterial: "修补材料"
        case .toothbrush: "牙刷"
        case .towel: "毛巾"
        case .toiletPaper: "厕纸"
        case .trowel: "猫洞铲"
        case .sunscreen: "防晒霜"
        case .insectRepellent: "驱虫剂"
        case .menstrualProduct: "生理用品"
        case .waistPack: "腰包"
        case .key: "钥匙"
        case .document: "证件"
        case .food: "食品"
        case .drinkingWater: "饮水"
        case .fuel: "燃料"
        }
    }
}
