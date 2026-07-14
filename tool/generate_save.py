import json
from uuid import uuid4
import datetime

def make_interface(name, ip="", mask="", gateway=None, mac="00:00:00:00:00:00", status="up", conn_id=None):
    return {
        "name": name,
        "ipAddress": ip,
        "subnetMask": mask,
        "macAddress": mac,
        "defaultGateway": gateway,
        "dnsServer": None,
        "status": status,
        "connectedToConnectionId": conn_id,
        "isDhcpClient": False
    }

router0_id = str(uuid4())
router1_id = str(uuid4())
wr_id = str(uuid4())
pc0_id = str(uuid4())
pc1_id = str(uuid4())
sm_id = str(uuid4())

c_r0_r1 = str(uuid4())
c_r0_pc0 = str(uuid4())
c_r1_pc1 = str(uuid4())
c_r1_wr = str(uuid4())
c_wr_sm = str(uuid4())

topology = {
    "name": "Topologi Tiga Subnet",
    "description": "R0(PC0) -> R1(PC1) -> WR(Smartphone)",
    "createdAt": datetime.datetime.now().isoformat(),
    "modifiedAt": datetime.datetime.now().isoformat(),
    "devices": [
        {
            "id": router0_id,
            "type": "router",
            "hostname": "Router0",
            "positionX": 300,
            "positionY": 300,
            "interfaces": [
                make_interface("GigabitEthernet 0/0", "192.168.1.1", "255.255.255.0", mac="00:11:22:33:44:01", conn_id=c_r0_r1),
                make_interface("GigabitEthernet 0/1", "192.168.2.1", "255.255.255.0", mac="00:11:22:33:44:02", conn_id=c_r0_pc0),
                make_interface("GigabitEthernet 0/2", mac="00:11:22:33:44:03", status="down"),
                make_interface("GigabitEthernet 0/3", mac="00:11:22:33:44:04", status="down")
            ],
            "routingTable": [
                {
                    "destination": "192.168.3.0",
                    "subnetMask": "255.255.255.0",
                    "nextHop": "192.168.1.2",
                    "exitInterface": "GigabitEthernet 0/0"
                },
                {
                    "destination": "192.168.4.0",
                    "subnetMask": "255.255.255.0",
                    "nextHop": "192.168.1.2",
                    "exitInterface": "GigabitEthernet 0/0"
                }
            ],
            "isSelected": False
        },
        {
            "id": router1_id,
            "type": "router",
            "hostname": "Router1",
            "positionX": 600,
            "positionY": 300,
            "interfaces": [
                make_interface("GigabitEthernet 0/0", "192.168.1.2", "255.255.255.0", mac="00:22:33:44:55:01", conn_id=c_r0_r1),
                make_interface("GigabitEthernet 0/1", "192.168.3.1", "255.255.255.0", mac="00:22:33:44:55:02", conn_id=c_r1_pc1),
                make_interface("GigabitEthernet 0/2", "192.168.4.1", "255.255.255.0", mac="00:22:33:44:55:03", conn_id=c_r1_wr),
                make_interface("GigabitEthernet 0/3", mac="00:22:33:44:55:04", status="down")
            ],
            "routingTable": [
                {
                    "destination": "192.168.2.0",
                    "subnetMask": "255.255.255.0",
                    "nextHop": "192.168.1.1",
                    "exitInterface": "GigabitEthernet 0/0"
                }
            ],
            "isSelected": False
        },
        {
            "id": wr_id,
            "type": "wirelessRouter",
            "hostname": "Wireless Router0",
            "positionX": 900,
            "positionY": 300,
            "interfaces": [
                make_interface("Wlan 0/0", mac="00:AA:BB:CC:DD:01", conn_id=c_r1_wr),
                make_interface("Wlan 0/1", mac="00:AA:BB:CC:DD:02", conn_id=c_wr_sm),
                make_interface("Wlan 0/2", mac="00:AA:BB:CC:DD:03", status="down"),
                make_interface("Wlan 0/3", mac="00:AA:BB:CC:DD:04", status="down"),
                make_interface("Wlan 0/4", mac="00:AA:BB:CC:DD:05", status="down")
            ],
            "routingTable": [],
            "isSelected": False
        },
        {
            "id": pc0_id,
            "type": "pc",
            "hostname": "PC0",
            "positionX": 150,
            "positionY": 450,
            "interfaces": [
                make_interface("Ethernet 0/0", "192.168.2.10", "255.255.255.0", gateway="192.168.2.1", mac="00:11:AA:BB:CC:01", conn_id=c_r0_pc0)
            ],
            "routingTable": [],
            "isSelected": False
        },
        {
            "id": pc1_id,
            "type": "pc",
            "hostname": "PC1",
            "positionX": 600,
            "positionY": 450,
            "interfaces": [
                make_interface("Ethernet 0/0", "192.168.3.10", "255.255.255.0", gateway="192.168.3.1", mac="00:11:AA:BB:CC:02", conn_id=c_r1_pc1)
            ],
            "routingTable": [],
            "isSelected": False
        },
        {
            "id": sm_id,
            "type": "smartphone",
            "hostname": "Smartphone0",
            "positionX": 1050,
            "positionY": 450,
            "interfaces": [
                make_interface("Wlan 0/0", "192.168.4.10", "255.255.255.0", gateway="192.168.4.1", mac="00:11:AA:BB:CC:03", conn_id=c_wr_sm)
            ],
            "routingTable": [],
            "isSelected": False
        }
    ],
    "connections": [
        {
            "id": c_r0_r1,
            "deviceAId": router0_id,
            "interfaceAName": "GigabitEthernet 0/0",
            "deviceBId": router1_id,
            "interfaceBName": "GigabitEthernet 0/0",
            "cableType": "crossover",
            "state": "connected"
        },
        {
            "id": c_r0_pc0,
            "deviceAId": router0_id,
            "interfaceAName": "GigabitEthernet 0/1",
            "deviceBId": pc0_id,
            "interfaceBName": "Ethernet 0/0",
            "cableType": "straight",
            "state": "connected"
        },
        {
            "id": c_r1_pc1,
            "deviceAId": router1_id,
            "interfaceAName": "GigabitEthernet 0/1",
            "deviceBId": pc1_id,
            "interfaceBName": "Ethernet 0/0",
            "cableType": "straight",
            "state": "connected"
        },
        {
            "id": c_r1_wr,
            "deviceAId": router1_id,
            "interfaceAName": "GigabitEthernet 0/2",
            "deviceBId": wr_id,
            "interfaceBName": "Wlan 0/0",
            "cableType": "straight",
            "state": "connected"
        },
        {
            "id": c_wr_sm,
            "deviceAId": wr_id,
            "interfaceAName": "Wlan 0/1",
            "deviceBId": sm_id,
            "interfaceBName": "Wlan 0/0",
            "cableType": "wireless",
            "state": "connected"
        }
    ]
}

with open(r"c:\Users\SHIN\Documents\Topologi_Tiga_Subnet.firelink", "w") as f:
    json.dump(topology, f, indent=2)
