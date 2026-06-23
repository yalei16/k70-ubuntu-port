[Defines]
  PLATFORM_NAME           = vermeer
  PLATFORM_GUID           = 12345678-1234-1234-1234-123456789ABC
  PLATFORM_VERSION        = 0.1
  DSC_SPECIFICATION       = 0x00010005
  OUTPUT_DIRECTORY        = Build/$(PLATFORM_NAME)
  SUPPORTED_ARCHITECTURES = AARCH64
  BUILD_TARGETS           = DEBUG|RELEASE
  SKUID_IDENTIFIER        = DEFAULT
  FLASH_DEFINITION        = Platform/Qualcomm/sm8550/vermeer/vermeer.fdf

[BuildOptions]
  GCC:*_*_AARCH64_CC_FLAGS = -DMEMORY_12GB=1

[Packages]
  MdePkg/MdePkg.dec
  MdeModulePkg/MdeModulePkg.dec
  Silicon/Qualcomm/sm8550/sm8550.dec
  Platform/Qualcomm/sm8550/vermeer/vermeer.dec

[LibraryClasses]
  # 使用 SM8550 通用库
  PlatformMemoryMapLib|Platform/Qualcomm/sm8550/vermeer/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.inf
  PlatformPeiLib|Platform/Qualcomm/sm8550/vermeer/Library/PlatformPeiLib/PlatformPeiLib.inf

[PcdsFixedAtBuild]
  # 内存映射 - 需根据实际硬件调整
  gArmTokenSpaceGuid.PcdSystemMemoryBase|0x80000000
  gArmTokenSpaceGuid.PcdSystemMemorySize|0x300000000

  # 串口调试
  gEfiMdePkgTokenSpaceGuid.PcdUartDefaultBaudRate|115200
  gEfiMdePkgTokenSpaceGuid.PcdUartDefaultReceiveFifoDepth|32

[Components]
  # 设备特定驱动
  Platform/Qualcomm/sm8550/vermeer/Drivers/PanelDxe/PanelDxe.inf
  Platform/Qualcomm/sm8550/vermeer/Drivers/ButtonsDxe/ButtonsDxe.inf

[Components.AARCH64]
  # 应用
  Platform/Qualcomm/sm8550/vermeer/Application/SimpleInit/SimpleInit.inf
