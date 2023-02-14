# Ets表设计

## 仿真任务表

所有的key都是二进制格式
| key         |     | value           |     |
| ----------- | --- | --------------- | --- |
| counter     |     | 消息计数器           |     |
| sock_list   | x   | 仿真器socket列表     |     |
| config_list |     | 仿真器配置           |     |
| sid_sock    |     | sid 对应的 sock 字典 |     |
| sock_sid    |     | sock 对应 sid 字典  |     |
| sid_set     |     | sid 集合          |     |
| sid_pid            |     | sid 对应pid 字典 |     |
| sidxxx_buff( sid名加上_buff) |     | 存储对应数据 |     |
|             |     |                 |     |
