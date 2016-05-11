//
//  YContactsManager.m
//  YAddressBookDemo
//
//  Created by YueWen on 16/5/6.
//  Copyright © 2016年 YueWen. All rights reserved.
//

#import "YContactsManager.h"
#import "YContactObject.h"
#import "YContactObjectManager.h"
@import AddressBook;



typedef void(^ContactDidObatinBlock)(NSArray <YContactObject *> *);


@interface YContactsManager ()

@property (nonatomic, assign, nullable)ABAddressBookRef addressBook;//请求通讯录的结构体对象
@property (nonatomic, copy) ContactDidObatinBlock contactsDidObtainBlockHandle;

@end



@implementation YContactsManager


-(instancetype)init
{
    if (self = [super init])
    {
        self.addressBook = ABAddressBookCreate();

        /**
         *  注册通讯录变动的回调
         *
         *  @param self.addressBook          注册的addressBook
         *  @param addressBookChangeCallBack 变动之后进行的回调方法
         *  @param void                      传参，这里是将自己作为参数传到方法中
         */
        ABAddressBookRegisterExternalChangeCallback(self.addressBook,  addressBookChangeCallBack, (__bridge_retained void *)(self));
        
    }
    
    return self;
}


void addressBookChangeCallBack(ABAddressBookRef addressBook, CFDictionaryRef info, void *context)
{
    //coding when addressBook did changed
    NSLog(@"通讯录发生变化啦");
    
    //初始化对象
    YContactsManager * contactManager = CFBridgingRelease(context);
    
    //重新获取联系人
    [contactManager obtainContacts:addressBook];
    
}





+(instancetype)shareInstance
{
    static YContactsManager * addressBookManager = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        addressBookManager = [[YContactsManager alloc]init];
        
    });
    
    return addressBookManager;
}


-(void)dealloc
{
    
    //移除监听
    ABAddressBookUnregisterExternalChangeCallback(self.addressBook, addressBookChangeCallBack, (__bridge void *)(self));
    
    //释放
    CFRelease(self.addressBook);
}






#pragma mark - 请求通讯录
//请求通讯录
-(void)requestContactsComplete:(void (^)(NSArray<YContactObject *> * _Nonnull))completeBlock
{
    self.contactsDidObtainBlockHandle = completeBlock;
    [self checkAuthorizationStatus];
}



/**
 *  检测权限并作响应的操作
 */
- (void)checkAuthorizationStatus
{
    switch (ABAddressBookGetAuthorizationStatus())
    {
            //存在权限
        case kABAuthorizationStatusAuthorized:
            //获取通讯录
            [self obtainContacts:self.addressBook];
            break;
            
            //权限未知
        case kABAuthorizationStatusNotDetermined:
            //请求权限
            [self requestAuthorizationStatus];
            break;
            
            //如果没有权限
        case kABAuthorizationStatusDenied:
        case kABAuthorizationStatusRestricted://需要提示
            //弹窗提醒
            [self showAlertController];
        
            break;
        default:
            break;
    }
}



/**
 *  获取通讯录中的联系人
 */
- (void)obtainContacts:(ABAddressBookRef)addressBook
{
    
    //按照添加时间请求所有的联系人
    CFArrayRef contants = ABAddressBookCopyArrayOfAllPeople(addressBook);
    
    //按照排序规则请求所有的联系人
//    ABRecordRef recordRef = ABAddressBookCopyDefaultSource(addressBook);
//    CFArrayRef contants = ABAddressBookCopyArrayOfAllPeopleInSourceWithSortOrdering(addressBook, recordRef, kABPersonSortByFirstName);

    //存放所有联系人的数组
    NSMutableArray <YContactObject *> * contacts = [NSMutableArray arrayWithCapacity:0];
    
    //遍历获取所有的数据
    for (NSInteger i = 0; i < CFArrayGetCount(contants); i++)
    {
        //获得People对象
        ABRecordRef recordRef = CFArrayGetValueAtIndex(contants, i);
        
        //获得contact对象
        YContactObject * contactObject = [YContactObjectManager contantObject:recordRef];
        
        //添加对象
        [contacts addObject:contactObject];
    }
    
    //释放资源
    CFRelease(contants);
    
    //进行回调赋值
    ContactDidObatinBlock copyBlock  = self.contactsDidObtainBlockHandle;
    
    //进行数据回调
    copyBlock([NSArray arrayWithArray:contacts]);
}



/**
 *  请求通讯录的权限
 */
- (void)requestAuthorizationStatus
{
    //避免强引用
    __weak typeof(self) copy_self = self;
    
    ABAddressBookRequestAccessWithCompletion(self.addressBook, ^(bool granted, CFErrorRef error) {
       
        //权限得到允许
        if (granted == true)
        {
            //主线程获取联系人
            dispatch_async(dispatch_get_main_queue(), ^{
            
                [copy_self obtainContacts:self.addressBook];
                
            });
        }
    });
}



/**
 *  弹出提示AlertController
 */
- (void)showAlertController
{
    
}


@end
