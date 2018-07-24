# RITLAddressBookDemo
通过AddressBook.framework简单获取联系人的各种属性

AddressBook是Apple提供给我们获取系统联系人的一个很方便类库，与其说方便，其实刚开始还是比较崩溃的，从开发文档来看，它还是偏向于C语言，并且不在ARC的控制之下，虽然在iOS9.0之后会被`Contacts.framework`替代，但在工作中要对最低版本进行兼容，了解一下这个类库还是很有必要的。这里就介绍一下获取联系人信息的那些方法，对于修改，添加删除等操作，想留在下一篇介绍AddressBookUI这个类库的时候来写一下。

博客:[http://blog.csdn.net/runintolove/article/details/51371996](http://blog.csdn.net/runintolove/article/details/51371996)
<br>

## 获取权限

iOS6.0之后，苹果对于用户隐私就加强了，所有调用系统权限都需要用户授权才可以进行之后的操作，因此在获取通讯录的时候要检测一下有没有权限(这一点在定位，相机等操作上也都看出)：
```Objective-C
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
```

请求权限的方法如下:

```Objective-C
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
```
<br>

## 请求联系人列表

为Demo中是楼主自行构建的Model，因此代码就显得简略了好多，后面会附上CFRecord转模型的代码:

```Objective-C
/**
 *  获取通讯录中的联系人
 */
- (void)obtainContacts:(ABAddressBookRef)addressBook
{
    //按照添加时间请求所有的联系人
    CFArrayRef contants = ABAddressBookCopyArrayOfAllPeople(addressBook);
    
    //按照排序规则请求所有的联系人
//    ABRecordRef recordRef = ABAddressBookCopyDefaultSource(addressBook);
      //这里的firstName是按照姓名属性中的firstName来排序的，并不是按照全称来排序
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
    
    //释放资源，因为不在ARC下，retain或者copy之后记得release
    CFRelease(contants);
    
    //进行回调赋值
    ContactDidObatinBlock copyBlock  = self.contactsDidObtainBlockHandle;
    
    //进行数据回调
    copyBlock([NSArray arrayWithArray:contacts]);
}
```
<br>

## 获取联系人的姓名属性

为了让代码可读性更好一点，在进行转型的时候写了如下方法，是为了方便将CFStringRef通过桥接__bridge转型成NSString对象:
```Objective-C
/**
 *  根据属性key获得NSString
 *
 *  @param property 属性key
 */
+ (NSString *)contactProperty:(ABPropertyID) property
{
    return (__bridge NSString *)(ABRecordCopyValue(self.recordRef, property));
}
```

获取姓名相关属性方法如下:

```Objective-C
/**
 *  获得姓名的相关属性
 */
+ (YContactNameObject *)contactNameProperty
{
    //初始化对象
    YContactNameObject * nameObject = [[YContactNameObject alloc]init];
    
    nameObject.givenName = [self contactProperty:kABPersonFirstNameProperty];                   //名字
    nameObject.familyName = [self contactProperty:kABPersonLastNameProperty];                   //姓氏
    nameObject.middleName = [self contactProperty:kABPersonMiddleNameProperty];                 //名字中的信仰名称（比如Jane·K·Frank中的K）
    nameObject.namePrefix = [self contactProperty:kABPersonPrefixProperty];                     //名字前缀
    nameObject.nameSuffix = [self contactProperty:kABPersonSuffixProperty];                     //名字后缀
    nameObject.nickName = [self contactProperty:kABPersonNicknameProperty];                     //名字昵称
    nameObject.phoneticGivenName = [self contactProperty:kABPersonFirstNamePhoneticProperty];   //名字的拼音音标
    nameObject.phoneticFamilyName = [self contactProperty:kABPersonLastNamePhoneticProperty];   //姓氏的拼音音标
    nameObject.phoneticMiddleName = [self contactProperty:kABPersonMiddleNamePhoneticProperty]; //英文信仰缩写字母的拼音音标
    
    return nameObject;
}
```
<br>

## 获取联系人的类型

```Objective-C
/**
 *  获得联系人类型信息
 */
+ (YContactType)contactTypeProperty
{
    //获得类型属性
    CFNumberRef typeIndex = ABRecordCopyValue(self.recordRef, kABPersonKindProperty);
    
    //表示是公司联系人
    if (CFNumberCompare(typeIndex, kABPersonKindOrganization, nil) == kCFCompareEqualTo)
    {
        //释放资源
        CFRelease(typeIndex);
        
        return YContactTypeOrigination;
    }
    
    return YContactTypePerson;
}
```
<br>

## 获取联系人的头像图片

```Objective-C
/**
 *  获得联系人的头像图片
 */
+ (UIImage *)contactHeadImagePropery
{
    //首先判断是否存在头像
    if (ABPersonHasImageData(self.recordRef) == false)//没有头像，返回nil
    {
        return nil;
    }
    
    //开始获得头像信息
    NSData * imageData = (__bridge NSData *)(ABPersonCopyImageData(self.recordRef));
    
    //获得头像原图
//    NSData * imageData = CFBridgingRelease(ABPersonCopyImageDataWithFormat(self.recordRef, kABPersonImageFormatOriginalSize));
    
    return [UIImage imageWithData:imageData];
}
```
<br>

## 获取联系人的电话信息

```Objective-C
/**
 *  获得电话号码对象数组
 */
+ (NSArray <YContactPhoneObject *> *)contactPhoneProperty
{
    //外传数组
    NSMutableArray <YContactPhoneObject *> * phones = [NSMutableArray arrayWithCapacity:0];
    
    //获得电话号码的多值属性
    ABMultiValueRef values = ABRecordCopyValue(self.recordRef, kABPersonPhoneProperty);
    
    for (NSInteger i = 0; i < ABMultiValueGetCount(values); i++)
    {
        YContactPhoneObject * phoneObject = [[YContactPhoneObject alloc]init];
        
        //开始赋值
        phoneObject.phoneTitle = (__bridge NSString *)ABAddressBookCopyLocalizedLabel(ABMultiValueCopyLabelAtIndex(values, i)); //电话描述(如住宅、工作..)
        phoneObject.phoneNumber = (__bridge NSString *)ABMultiValueCopyValueAtIndex(values, i);                                 //电话号码
         
        //添加数据
        [phones addObject:phoneObject];
    }
    
    //释放资源
    CFRelease(values);

    return [NSArray arrayWithArray:phones];
}
```
<br>

## 获取联系人的工作信息

```Objective-C
/**
 *  获得工作的相关属性
 */
+ (YContactJobObject *)contactJobProperty
{
    YContactJobObject * jobObject = [[ YContactJobObject alloc]init];
    
    jobObject.organizationName = [self contactProperty:kABPersonOrganizationProperty]; //公司(组织)名称
    jobObject.departmentName = [self contactProperty:kABPersonDepartmentProperty];     //部门
    jobObject.jobTitle = [self contactProperty:kABPersonJobTitleProperty];             //职位
    
    return jobObject;
}
```
<br>

## 获取联系人的邮件信息

```Objective-C
/**
 *  获得Email对象的数组
 */
+ (NSArray <YContactEmailObject *> *)contactEmailProperty
{
    //外传数组
    NSMutableArray <YContactEmailObject *> * emails = [NSMutableArray arrayWithCapacity:0];
    
    //获取多值属性
    ABMultiValueRef values = ABRecordCopyValue(self.recordRef, kABPersonEmailProperty);
    
    //遍历添加
    for (NSInteger i = 0; i < ABMultiValueGetCount(values); i++)
    {
        YContactEmailObject * emailObject = [[YContactEmailObject alloc]init];
        
        emailObject.emailTitle = (__bridge NSString *)(ABAddressBookCopyLocalizedLabel(ABMultiValueCopyLabelAtIndex(values, i)));  //邮件描述
        emailObject.emailAddress = (__bridge NSString *)(ABMultiValueCopyValueAtIndex(values, i));                                 //邮件地址
        //添加
        [emails addObject:emailObject];
    }
    
    //释放资源
    CFRelease(values);
    
    return [NSArray arrayWithArray:emails];
}
```

<br>

## 获取联系人的地址信息

```Objective-C
/**
 *  获得Address对象的数组
 */
+ (NSArray <YContactAddressObject *> *)contactAddressProperty
{
    //外传数组
    NSMutableArray <YContactAddressObject *> * addresses = [NSMutableArray arrayWithCapacity:0];
    
    //获取多指属性
    ABMultiValueRef values = ABRecordCopyValue(self.recordRef, kABPersonAddressProperty);
    
    //遍历添加
    for (NSInteger i = 0; i < ABMultiValueGetCount(values); i++)
    {
        YContactAddressObject * addressObject = [[YContactAddressObject alloc]init];
        
        //赋值
        addressObject.addressTitle = (__bridge NSString *)ABAddressBookCopyLocalizedLabel((ABMultiValueCopyLabelAtIndex(values, i)));                    //地址标签
        
        //获得属性字典
        NSDictionary * dictionary = (__bridge NSDictionary *)ABMultiValueCopyValueAtIndex(values, i);
        
        //开始赋值
        addressObject.country = [dictionary valueForKey:(__bridge NSString *)kABPersonAddressCountryKey];               //国家
        addressObject.city = [dictionary valueForKey:(__bridge NSString *)kABPersonAddressCityKey];                     //城市
        addressObject.state = [dictionary valueForKey:(__bridge NSString *)kABPersonAddressStateKey];                   //省(州)
        addressObject.street = [dictionary valueForKey:(__bridge NSString *)kABPersonAddressStreetKey];                 //街道
        addressObject.postalCode = [dictionary valueForKey:(__bridge NSString *)kABPersonAddressZIPKey];                //邮编
        addressObject.ISOCountryCode = [dictionary valueForKey:(__bridge NSString *)kABPersonAddressCountryCodeKey];    //ISO国家编号
        
        //添加数据
        [addresses addObject:addressObject];
    }
    
    //释放资源
    CFRelease(values);
    
    return [NSArray arrayWithArray:addresses];
    
}
```
<br>

## 获取联系人的生日信息

```Objective-C
/**
 *  根据属性key获得NSDate
 *
 *  @param property 属性key
 *
 *  @return NSDate对象
 */
+ (NSDate *)contactDateProperty:(ABPropertyID) property
{
    return (__bridge NSDate *)(ABRecordCopyValue(self.recordRef, property));
}

/**
 *  获得生日的相关属性
 */
+ (YContactBrithdayObject *)contactBrithdayProperty
{
    //实例化对象
    YContactBrithdayObject * brithdayObject = [[YContactBrithdayObject alloc]init];
    
    //生日的日历
    brithdayObject.brithdayDate = [self contactDateProperty:kABPersonBirthdayProperty];         //生日的时间对象
    
    //获得农历日历属性的字典
    NSDictionary * brithdayDictionary = (__bridge NSDictionary *)(ABRecordCopyValue(self.recordRef, kABPersonAlternateBirthdayProperty));
    
    //农历日历的属性，设置为农历属性的时候，此字典存在数值
    if (brithdayDictionary != nil)
    {
        
        brithdayObject.calendar = [brithdayDictionary valueForKey:@"calendar"];                                 //农历生日的标志位,比如“chinese”
        
        //农历生日的相关存储属性
        brithdayObject.era = [(NSNumber *)[brithdayDictionary valueForKey:@"era"] integerValue];                //纪元
        brithdayObject.year = [(NSNumber *)[brithdayDictionary valueForKey:@"year"] integerValue];              //年份,六十组干支纪年的索引数，比如12年为壬辰年，为循环的29,此数字为29

        brithdayObject.month = [(NSNumber *)[brithdayDictionary valueForKey:@"month"] integerValue];            //月份
        brithdayObject.leapMonth = [(NSNumber *)[brithdayDictionary valueForKey:@"isLeapMonth"] boolValue];     //是否是闰月
        brithdayObject.day = [(NSNumber *)[brithdayDictionary valueForKey:@"day"] integerValue];                //日期
        
    }

    //返回对象
    return brithdayObject;
}
```
<br>

## 获取联系人的即时通信信息

```Objective-C
/**
 *  获得即时通信账号相关信息
 */
+ (NSArray <YContactInstantMessageObject *> *)contactMessageProperty
{
    //存放数组
    NSMutableArray <YContactInstantMessageObject *> * instantMessages = [NSMutableArray arrayWithCapacity:0];
    
    //获取数据字典
    ABMultiValueRef messages = ABRecordCopyValue(self.recordRef, kABPersonInstantMessageProperty);
    
    //遍历获取值
    for (NSInteger i = 0; i < ABMultiValueGetCount(messages); i++)
    {
        //获取属性字典
        NSDictionary * messageDictionary = CFBridgingRelease(ABMultiValueCopyValueAtIndex(messages, i));
        
        //实例化
        YContactInstantMessageObject * instantMessageObject = [[YContactInstantMessageObject alloc]init];
        
        instantMessageObject.service = [messageDictionary valueForKey:@"service"];          //服务名称(如QQ)
        instantMessageObject.userName = [messageDictionary valueForKey:@"username"];        //服务账号(如QQ号)
        
        //添加
        [instantMessages addObject:instantMessageObject];
    }

    return [NSArray arrayWithArray:instantMessages];
}
```
<br>

## 获得联系人的关联人信息

```Objective-C
/**
 *  获得联系人的关联人信息
 */
+ (NSArray <YContactRelatedNamesObject *> *)contactRelatedNamesProperty
{
    //存放数组
    NSMutableArray <YContactRelatedNamesObject *> * relatedNames = [NSMutableArray arrayWithCapacity:0];
    
    //获得多值属性
    ABMultiValueRef names = ABRecordCopyValue(self.recordRef, kABPersonRelatedNamesProperty);
    
    //遍历赋值
    for (NSInteger i = 0; i < ABMultiValueGetCount(names); i++)
    {
        //初始化
        YContactRelatedNamesObject * relatedName = [[YContactRelatedNamesObject alloc]init];
        
        //赋值
        relatedName.relatedTitle = CFBridgingRelease(ABAddressBookCopyLocalizedLabel(ABMultiValueCopyLabelAtIndex(names, i))); //关联的标签(如friend)
        relatedName.relatedName = CFBridgingRelease(ABMultiValueCopyValueAtIndex(names, i));                                    //关联的名称(如联系人姓名)
        
        //添加
        [relatedNames addObject:relatedName];
    }
    
    return [NSArray arrayWithArray:relatedNames];
}
```
<br>

## 获取联系人的社交简介信息

```Objective-C
/**
 *  获得联系人的社交简介信息
 */
+ (NSArray <YContactSocialProfileObject *> *)contactSocialProfilesProperty
{
    //外传数组
    NSMutableArray <YContactSocialProfileObject *> * socialProfiles = [NSMutableArray arrayWithCapacity:0];
    
    //获得多值属性
    ABMultiValueRef profiles = ABRecordCopyValue(self.recordRef, kABPersonSocialProfileProperty);
    
    //遍历取值
    for (NSInteger i = 0; i < ABMultiValueGetCount(profiles); i++)
    {
        //初始化对象
        YContactSocialProfileObject * socialProfileObject = [[YContactSocialProfileObject alloc]init];
        
        //获取属性值
        NSDictionary * profileDictionary = CFBridgingRelease(ABMultiValueCopyValueAtIndex(profiles, i));
        
        //开始赋值
        socialProfileObject.socialProfileTitle = [profileDictionary valueForKey:@"service"];    //社交简介(如sinaweibo)
        socialProfileObject.socialProFileAccount = [profileDictionary valueForKey:@"username"]; //社交地址(如123456)
        socialProfileObject.socialProFileUrl = [profileDictionary valueForKey:@"url"];          //社交链接的地址(按照上面两项自动为http://weibo.com/n/123456)
        
        //添加
        [socialProfiles addObject:socialProfileObject];   
    }
    return [NSArray arrayWithArray:socialProfiles];
}
```
<br>

## 获取联系人的备注信息

```Objective-C
//备注
contactObject.note = [self contactProperty:kABPersonNoteProperty];               
```
<br> 

## 获取联系人的创建时间
```
//创建时间
contactObject.creationDate = [self contactDateProperty:kABPersonCreationDateProperty];
```
<br>

## 获取联系人的最近修改时间

```Objective-C
//最近一次修改的时间
contactObject.modificationDate = [self contactDateProperty:kABPersonModificationDateProperty];
```
<br>

## 接收外界通讯录发生变化的方法

在初始化AddressBook的时候为它注册一个通知

```
//创建一个AddressBook
self.addressBook = ABAddressBookCreate();
        
/**
 *  注册通讯录变动的回调
 *
 *  @param self.addressBook          注册的addressBook
 *  @param addressBookChangeCallBack 变动之后进行的回调方法
 *  @param void                      传参，这里是将自己作为参数传到方法中,
 *  将自己传过去的时候，一定要用__bridge_retained一下，如果不retained，会发生内存泄露，计数器不正确，导致程序崩溃
 */
ABAddressBookRegisterExternalChangeCallback(self.addressBook,  addressBookChangeCallBack, (__bridge_retained void *)(self));
```

在外面自己写回调的方法，这个方法是外界的通讯录发生增删改查之后，再次回到此App的时候才会触发的方法

```C++
void addressBookChangeCallBack(ABAddressBookRef addressBook, CFDictionaryRef info, void *context)
{
    //coding when addressBook did changed
    NSLog(@"通讯录发生变化啦");
    
	//初始化对象，这里是将参数转成对象的方法
	YContactsManager * contactManager = CFBridgingRelease(context);

}
```
